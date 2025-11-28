// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Hidden Code Quality (Aggregate-Only, No Personalization) — Zama FHEVM
 *
 * - Inputs: encrypted metrics in 0..100 (coverage ↑, style ↑, complexity ↓, bugs ↓).
 * - Policy: encrypted thresholds (min for good, or max for good).
 * - Per submission: 4 checks → each worth 25 points via FHE.select → composite in 0..100.
 * - Aggregates: sumScore (euint16), submissions (uint16 plain, capped).
 * - Publish: make sumScore publicly decryptable; average computed off-chain as sumScore_dec / submissions.
 *
 * No FHE division or casting is used.
 */

import {
    FHE,
    ebool,
    euint16,
    externalEuint16
} from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract HiddenCodeQualityAggregate is ZamaEthereumConfig {
    /* ───────── Version / Ownership ───────── */

    function version() external pure returns (string memory) {
        return "HiddenCodeQualityAggregate/2.0.0";
    }

    address public owner;
    modifier onlyOwner(){ require(msg.sender == owner, "Not owner"); _; }
    constructor(){
        owner = msg.sender;

        // Default thresholds: permissive (everything passes)
        tCovMin   = FHE.asEuint16(0);
        tStyleMin = FHE.asEuint16(0);
        tComplMax = FHE.asEuint16(100);
        tBugsMax  = FHE.asEuint16(100);

        sumScore   = FHE.asEuint16(0);
        submissions = 0;

        FHE.allowThis(tCovMin);
        FHE.allowThis(tStyleMin);
        FHE.allowThis(tComplMax);
        FHE.allowThis(tBugsMax);
        FHE.allowThis(sumScore);
    }

    function transferOwnership(address n) external onlyOwner {
        require(n != address(0), "Zero owner"); owner = n;
    }

    /* ───────── Encrypted Threshold Policy ───────── */

    // coverage >= tCovMin
    euint16 private tCovMin;
    // style   >= tStyleMin
    euint16 private tStyleMin;
    // complexity <= tComplMax  (lower is better)
    euint16 private tComplMax;
    // bugs       <= tBugsMax   (lower is better)
    euint16 private tBugsMax;

    event PolicyUpdated(bytes32 tCovMinH, bytes32 tStyleMinH, bytes32 tComplMaxH, bytes32 tBugsMaxH, bool encryptedInputs);

    function setPolicyEncrypted(
        externalEuint16 tCovMinExt,
        externalEuint16 tStyleMinExt,
        externalEuint16 tComplMaxExt,
        externalEuint16 tBugsMaxExt,
        bytes calldata  proof
    ) external onlyOwner {
        tCovMin   = FHE.fromExternal(tCovMinExt,   proof);
        tStyleMin = FHE.fromExternal(tStyleMinExt, proof);
        tComplMax = FHE.fromExternal(tComplMaxExt, proof);
        tBugsMax  = FHE.fromExternal(tBugsMaxExt,  proof);

        FHE.allowThis(tCovMin);
        FHE.allowThis(tStyleMin);
        FHE.allowThis(tComplMax);
        FHE.allowThis(tBugsMax);

        emit PolicyUpdated(
            FHE.toBytes32(tCovMin),
            FHE.toBytes32(tStyleMin),
            FHE.toBytes32(tComplMax),
            FHE.toBytes32(tBugsMax),
            true
        );
    }

    /// DEV ONLY
    function setPolicyPlain(uint16 covMin, uint16 styleMin, uint16 complMax, uint16 bugsMax) external onlyOwner {
        require(covMin<=100 && styleMin<=100 && complMax<=100 && bugsMax<=100, "0..100 only");
        tCovMin   = FHE.asEuint16(covMin);
        tStyleMin = FHE.asEuint16(styleMin);
        tComplMax = FHE.asEuint16(complMax);
        tBugsMax  = FHE.asEuint16(bugsMax);

        FHE.allowThis(tCovMin);
        FHE.allowThis(tStyleMin);
        FHE.allowThis(tComplMax);
        FHE.allowThis(tBugsMax);

        emit PolicyUpdated(
            FHE.toBytes32(tCovMin),
            FHE.toBytes32(tStyleMin),
            FHE.toBytes32(tComplMax),
            FHE.toBytes32(tBugsMax),
            false
        );
    }

    function makePolicyPublic() external onlyOwner {
        FHE.makePubliclyDecryptable(tCovMin);
        FHE.makePubliclyDecryptable(tStyleMin);
        FHE.makePubliclyDecryptable(tComplMax);
        FHE.makePubliclyDecryptable(tBugsMax);
    }

    function getPolicyHandles() external view returns (bytes32,bytes32,bytes32,bytes32) {
        return (FHE.toBytes32(tCovMin), FHE.toBytes32(tStyleMin), FHE.toBytes32(tComplMax), FHE.toBytes32(tBugsMax));
    }

    /* ───────── Aggregates (Encrypted sum, plain counter) ───────── */

    // sum of composite scores (each 0..100)
    euint16 private sumScore;
    // plain count (not sensitive), capped to avoid overflow in euint16 sum
    uint16  public submissions;

    event SubmissionIngested(bytes32 compositeHandle, bytes32 newSumHandle, uint16 newCount);
    event SumPublished(bytes32 sumHandle, uint16 atCount);

    /**
     * @notice Submit encrypted metrics (0..100 each). No per-user storage.
     * Scoring: 4 checks × 25 points = 0..100
     */
    function submitMetrics(
        externalEuint16 covExt,
        externalEuint16 styleExt,
        externalEuint16 complExt,
        externalEuint16 bugsExt,
        bytes calldata  proof
    ) external {
        require(submissions < 600, "Submissions cap reached");

        euint16 cov   = FHE.fromExternal(covExt,   proof);
        euint16 style = FHE.fromExternal(styleExt, proof);
        euint16 compl = FHE.fromExternal(complExt, proof);
        euint16 bugs  = FHE.fromExternal(bugsExt,  proof);

        FHE.allowThis(cov); FHE.allowThis(style); FHE.allowThis(compl); FHE.allowThis(bugs);

        // Conditions
        ebool okCov   = FHE.ge(cov,   tCovMin);
        ebool okStyle = FHE.ge(style, tStyleMin);
        ebool okCompl = FHE.le(compl, tComplMax); // lower is better
        ebool okBugs  = FHE.le(bugs,  tBugsMax);  // lower is better

        euint16 zero   = FHE.asEuint16(0);
        euint16 blockV = FHE.asEuint16(25);

        // 25 points if true, else 0
        euint16 sc1 = FHE.select(okCov,   blockV, zero);
        euint16 sc2 = FHE.select(okStyle, blockV, zero);
        euint16 sc3 = FHE.select(okCompl, blockV, zero);
        euint16 sc4 = FHE.select(okBugs,  blockV, zero);

        euint16 composite = FHE.add(FHE.add(sc1, sc2), FHE.add(sc3, sc4)); // 0..100

        // aggregate
        sumScore = FHE.add(sumScore, composite);
        FHE.allowThis(sumScore);
        submissions += 1;

        emit SubmissionIngested(FHE.toBytes32(composite), FHE.toBytes32(sumScore), submissions);
    }

    /**
     * @notice Make the aggregate sum publicly decryptable. Off-chain average:
     *         avg = sumScore_dec / submissions  (0..100), if submissions>0.
     */
    function publishSum() external returns (bytes32 sumHandle) {
        FHE.makePubliclyDecryptable(sumScore);
        FHE.allowThis(sumScore);
        sumHandle = FHE.toBytes32(sumScore);
        emit SumPublished(sumHandle, submissions);
    }

    function getAggregateHandles() external view returns (bytes32 sumScoreH, uint16 submissionsCount) {
        return (FHE.toBytes32(sumScore), submissions);
    }

    function resetAggregates() external onlyOwner {
        sumScore = FHE.asEuint16(0);
        FHE.allowThis(sumScore);
        submissions = 0;
    }
}
