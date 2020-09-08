// SPDX-License-Identifier: MIT

pragma solidity <0.7.0;

library Shared {
    // Constants
    uint constant VERIFIERS_PATIENT_COUNT = 2;
    uint constant VERIFIERS_PATIENT_OLDEST = 52 weeks;
    
    uint constant MAX_GUARDIANS_PER_PATIENT = 5;
    uint constant VERIFIERS_GUARDIAN_CLAIM_COUNT = 1;
    uint constant VERIFIERS_GUARDIAN_CLAIM_OLDEST = 2 * 52 weeks;
    
    uint constant MAX_WARDS_PER_PATIENT = 5;
    uint constant VERIFIERS_WARDS_CLAIM_COUNT = 3;
    uint constant VERIFIERS_WARDS_CLAIM_OLDEST = 52 weeks;
    
    uint constant VERIFIERS_DOCTOR_COUNT = 4;
    uint constant VERIFIERS_DOCTOR_OLDEST = 3 * 52 weeks;
    
    uint constant VERIFIERS_HOSPITAL_COUNT = 4;
    uint constant VERIFIERS_HOSPITAL_OLDEST = 52 weeks;
    
    

    uint constant MIN_NUM_RA_VERS = 2;
    uint constant MAX_NUM_RA_VERS = 5;
    
    uint constant MIN_NUM_GUARD_VERS = 1;
    uint constant MAX_NUM_GUARD_VERS = 5;
    
    uint constant MIN_RGTO_COUNT = 2;
    uint constant MAX_RGTO_COUNT = 20;
    
    uint constant MAX_LATENCY = 1 hours;
    
    
    // Pure functions
    function min(uint a, uint b) public pure returns (uint) {
        return a < b ? a : b;
    }
    
    function max(uint a, uint b) public pure returns (uint) {
        return a > b ? a : b;
    }
    
    function between(uint x, uint a, uint b) public pure returns (uint) {
        if (x < a) return a;
        if (x > b) return b;
        return x;
    }


    
    // Claim struct and functions
    struct Claim {
        bool made;
        
        bool anyVerifier;
        uint numRequiredVerifiers;
        uint oldestDate; // duration of the oldest date before considering it expired
        
        address[] requiredVerifiers;
        
        address[] verifiers;
        uint[] dates; // used for expiring verifications
    }
    
    function verifyClaim(Claim storage claim) public {
        require(claim.made, "Claim must be made before being verified");
        
        bool didVerify = false;
        uint i;
        for (i = 0; i < claim.verifiers.length; i++) {
            if (claim.verifiers[i] == msg.sender) {
                didVerify = true;
                break;
            }
        }
        
        bool isValidVerifier = claim.anyVerifier;
        if (!isValidVerifier) {
            uint j;
            for (j = 0; j < claim.requiredVerifiers.length; j++) {
                if (claim.requiredVerifiers[i] == msg.sender) {
                    isValidVerifier = true;
                    break;
                }
            }
        }
        
        if (isValidVerifier) {
            if (!didVerify) {
                claim.verifiers.push(msg.sender);
                claim.dates.push(now);
                
            } else {
                claim.dates[i] = now;
            }
        }
    }
    
    function revokeClaim(Claim storage claim) public {
        for (uint i = 0; i < claim.verifiers.length; i++) {
            if (msg.sender == claim.verifiers[i]) {
                if (i < claim.verifiers.length - 1) {
                    claim.verifiers[i] = claim.verifiers[claim.verifiers.length - 1];
                    claim.dates[i] = claim.dates[claim.dates.length - 1];
                }
                
                claim.verifiers.pop();
                claim.dates.pop();
                
                break;
            }
        }
    }
    
    function isClaimVerified(Claim storage claim) view public returns(bool) {
        if (!claim.made || claim.verifiers.length < claim.numRequiredVerifiers) {
            return false;
        }
        
        uint verifications = 0;
        uint requiredVerifications = 0;
        
        for (uint i = 0; i < claim.verifiers.length; i++) {
            if (now - claim.dates[i] <= claim.oldestDate) {
                verifications += 1;
                
                if (!claim.anyVerifier) {
                    bool requiredVerifierFound = false;
                    for (uint j = 0; j < claim.requiredVerifiers.length; j++) {
                        if (claim.verifiers[i] == claim.requiredVerifiers[j]) {
                            requiredVerifierFound = true;
                            break;
                        }
                    }
                    if (requiredVerifierFound) {
                        requiredVerifications += 1;
                    }
                }
            }
        }
        
        if (claim.anyVerifier) {
            return verifications >= claim.numRequiredVerifiers;
        } else {
            return (verifications >= claim.numRequiredVerifiers) && (requiredVerifications >= claim.requiredVerifiers.length);
        }
    }
    
    
    // Regulatory agency member struct
    struct RAMember {
        bool registered;
        
    }
    
    
    // Person struct
    struct Person {
        bool registered;
        
        Claim patientVerified;
        Claim doctorVerified;
        
        // patient attributes
        bytes32[] bundleHashes;
        mapping(bytes32 => MedDoc) meddocs;
        
        address[] guardiansAddress;
        Claim[] guardiansClaim;
        
        bytes32[] pdrTokenIDs;
        mapping(bytes32 => PDReputationToken) pdrTokens;
        
        // guardian attributes
        address[] wardsAddress;
        Claim[] wardsClaim;
        
        // doctor attributes
        bytes32[] dofTokenIDs; // doctor->rgto file token IDs
        mapping(bytes32 => DOFileToken) dofTokens;
    }
    
    struct MedDoc {
        bool exists;
        
        uint requestCount;
        mapping(uint => Request) requests;
        
        uint defaultNumRAMVers;
        uint defaultNumGuardVers;
    }
    
    struct Request {
        bool exists;
        
        address doctor; // Requester
        
        uint requestTime; // Time of receiving a request
        uint minRGTOCount;
        uint maxRGTOCount;
        
        Claim patientVerifications;
        Claim RAMemberVerifications;
        Claim guardianVerifications;
        
        bool rgtosEvaluated;
        address[] rgtoAddresses;
        mapping(address => uint16) rgtoRatings;
    }
    
    struct PDReputationToken {
        bool exists;
        address doctorAddress;
    }

    struct DOFileToken {
        bool exists;
        address rgtoAddress;
        // TODO: maybe here we should have info about the file
    }
    
    
    // Hospital struct
    struct Hospital {
        bool registered;
        
        Claim hospitalVerified;
    }
    
    
    // Reputation-governed Trusted Oracle
    struct RGTO {
        bool registered;
        
        uint16 averageContractRating;
        uint16 contractRatingCount;
        uint16 averageDoctorRating;
        uint16 doctorRatingCount;
        
        bytes32[] odfTokenIDs; // rgto->doctor file token IDs
        mapping(bytes32 => ODFileToken) odfTokens;
    }

    struct ODFileToken {
        bool exists;
        address doctorAddress;
        // TODO: maybe here we should have info about the file
    }
}
