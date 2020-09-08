// SPDX-License-Identifier: MIT

pragma solidity <0.7.0;
pragma experimental ABIEncoderV2;

import "./Shared.sol";

contract RASC {
    // State variables
    address public owner;
    mapping (address => Shared.RAMember) public ramembers;
    mapping (address => Shared.Person) public persons;
    mapping (address => Shared.Hospital) public hospitals;
    mapping (address => Shared.RGTO) public rgtos;

    
    // Modifier
    modifier onlyOwner {
        require(msg.sender == owner, "Only regulatory agency smart contract owner can call this function");
        _;
    }
    
    modifier notOwner {
        require(msg.sender != owner, "Regulatory agency smart contract owner cannot call this function");
        _;
    }
    
    modifier notRegistered {
        require(
            !ramembers[msg.sender].registered &&
            !persons[msg.sender].registered &&
            !hospitals[msg.sender].registered &&
            !rgtos[msg.sender].registered,
            "Only unregistered entities can call this function");
        _;
    }
    
    modifier onlyRAMember {
        require(ramembers[msg.sender].registered, "Only regulatory agency members can call this function");
        _;
    }
    
    modifier onlyPerson {
        require(persons[msg.sender].registered, "Only a person can call this function");
        _;
    }
    
    // modifier onlyPatient {
    //     require(persons[msg.sender].isPatient, "Only patients can call this function");
    //     _;
    // }
    
    // modifier onlyGuardian {
    //     require(persons[msg.sender].isGuardian, "Only guardians can call this function");
    //     _;
    // }
    
    // modifier onlyDoctor {
    //     require(persons[msg.sender].isDoctor, "Only doctors can call this function");
    //     _;
    // }
    
    modifier onlyHospital {
        require(hospitals[msg.sender].registered, "Only hospitals can call this function");
        _;
    }
    
    modifier onlyRGTO {
        require(rgtos[msg.sender].registered, "Only RGTOs can call this function");
        _;
    }
    
    
    // Constructor
    constructor() public {
        owner = msg.sender;
    }
    
    
    // Register
    event newRAMemberRegistered(address ramember); // To inform RAM
    function registerRAMember(address ramemberAddress) public onlyOwner {
        ramembers[ramemberAddress].registered = true;
        
        emit newRAMemberRegistered(ramemberAddress);
    }
    
    event newPatientRegistered(address patient); // To inform RAM
    function registerPatient() public notRegistered notOwner {
        require(!persons[msg.sender].patientVerified.made, "This person already made a claim to be a patient");
        
        persons[msg.sender].registered = true;
        
        persons[msg.sender].patientVerified.made = true;
        persons[msg.sender].patientVerified.anyVerifier = true;
        persons[msg.sender].patientVerified.numRequiredVerifiers = Shared.VERIFIERS_PATIENT_COUNT;
        persons[msg.sender].patientVerified.oldestDate = Shared.VERIFIERS_PATIENT_OLDEST;
        
        emit newPatientRegistered(msg.sender);
    }
    
    event newDoctorRegistered(address doctor); // To inform RAM
    function registerDoctor() public {
        require(persons[msg.sender].registered, "Unregistered person cannot call this function");
        require(!persons[msg.sender].doctorVerified.made, "This person already made a claim to be a doctor");
        require(Shared.isClaimVerified(persons[msg.sender].patientVerified), "To register as a doctor, person must be a verified patient");
        
        persons[msg.sender].doctorVerified.made = true;
        persons[msg.sender].doctorVerified.anyVerifier = true;
        persons[msg.sender].doctorVerified.numRequiredVerifiers = Shared.VERIFIERS_DOCTOR_COUNT;
        persons[msg.sender].doctorVerified.oldestDate = Shared.VERIFIERS_DOCTOR_OLDEST;
        
        emit newDoctorRegistered(msg.sender);
    }
    
    event newHospitalRegistered(address hospital); // To inform RAM
    function registerHospital() public notRegistered notOwner {
        hospitals[msg.sender].registered = true;
        
        hospitals[msg.sender].hospitalVerified.made = true;
        hospitals[msg.sender].hospitalVerified.anyVerifier = true;
        hospitals[msg.sender].hospitalVerified.numRequiredVerifiers = Shared.VERIFIERS_HOSPITAL_COUNT;
        hospitals[msg.sender].hospitalVerified.oldestDate = Shared.VERIFIERS_HOSPITAL_OLDEST;
        
        emit newHospitalRegistered(msg.sender);
    }
    
    event newRGTORegistered(address rgto); // To inform RAM
    function registerRGTO() public notRegistered notOwner {
        rgtos[msg.sender].registered = true;
        
        rgtos[msg.sender].averageContractRating = 0;
        rgtos[msg.sender].contractRatingCount = 0;
        rgtos[msg.sender].averageDoctorRating = 0;
        rgtos[msg.sender].doctorRatingCount = 0;
        
        emit newRGTORegistered(msg.sender);
    }
    
    
    // Add and verify claims
    event newPatientVerification(address patient, address verifier); // To inform patient of new verification
    function verifyPatient(address personAddress) public onlyRAMember {
        Shared.verifyClaim(persons[personAddress].patientVerified);
        
        emit newPatientVerification(personAddress, msg.sender);
    }
    
    event newDoctorVerification(address doctor, address verifier); // To inform doctor of new verification
    function verifyDoctor(address personAddress) public onlyRAMember {
        Shared.verifyClaim(persons[personAddress].doctorVerified);
        
        emit newDoctorVerification(personAddress, msg.sender);
    }
    
    event guardianshipAdded(address guardian, address patient); // To inform the guardian
    function addGuardian(address guardianAddress) public onlyPerson {
        require(Shared.isClaimVerified(persons[msg.sender].patientVerified), "Patient must be verified before adding a guardian");
        require(persons[msg.sender].guardiansAddress.length < Shared.MAX_GUARDIANS_PER_PATIENT, "Maximum number of guardians reached");
        
        bool isGuardianNew = true;
        for (uint i = 0; i < persons[msg.sender].guardiansAddress.length; i++) {
            if (guardianAddress == persons[msg.sender].guardiansAddress[i]) {
                isGuardianNew = false;
                break;
            }
        }
        require(isGuardianNew, "Gardian is already added");
        
        persons[msg.sender].guardiansAddress.push(guardianAddress);
        
        Shared.Claim storage guardianClaim;
        guardianClaim.made = true;
        guardianClaim.anyVerifier = false;
        guardianClaim.numRequiredVerifiers = Shared.VERIFIERS_GUARDIAN_CLAIM_COUNT;
        guardianClaim.oldestDate = Shared.VERIFIERS_GUARDIAN_CLAIM_OLDEST;
        guardianClaim.requiredVerifiers.push(guardianAddress);
        persons[msg.sender].guardiansClaim.push(guardianClaim);
        
        emit guardianshipAdded(guardianAddress, msg.sender);
    }
    
    event guardianshipRemoved(address guardian, address patient); // To inform the guardian
    function removeGuardian(address guardianAddress) public onlyPerson {
        require(persons[msg.sender].guardiansAddress.length > 0, "Patient must have a guardian added already");
        
        for (uint i = 0; i < persons[msg.sender].guardiansAddress.length; i++) {
            if (persons[msg.sender].guardiansAddress[i] == guardianAddress) {
                if (i < persons[msg.sender].guardiansAddress.length) {
                    persons[msg.sender].guardiansAddress[i] = persons[msg.sender].guardiansAddress[persons[msg.sender].guardiansAddress.length - 1];
                    persons[msg.sender].guardiansClaim[i] = persons[msg.sender].guardiansClaim[persons[msg.sender].guardiansClaim.length - 1];
                }
                persons[msg.sender].guardiansAddress.pop();
                persons[msg.sender].guardiansClaim.pop();
                
                break;
            }
        }
        
        emit guardianshipRemoved(guardianAddress, msg.sender);
    }
    
    event guardianshipVerified(address guardian, address patient); // To inform the patient
    function verifyGuardian(address personAddress) public onlyPerson {
        require(persons[personAddress].guardiansAddress.length > 0, "Patient must have a guardian added already");
        
        for (uint i = 0; i < persons[personAddress].guardiansAddress.length; i++) {
            if (persons[personAddress].guardiansAddress[i] == msg.sender) {
                Shared.verifyClaim(persons[personAddress].guardiansClaim[i]);
            }
        }
        
        emit guardianshipVerified(msg.sender, personAddress);
    }
    
    event wardAdded(address ward, address person);
    function addWard(address wardAddress) public onlyPerson {
        require(Shared.isClaimVerified(persons[msg.sender].patientVerified), "Patient must be verified before adding a guardian");
        require(persons[msg.sender].wardsAddress.length < Shared.MAX_WARDS_PER_PATIENT, "Maximum number of wards reached");
        
        bool isWardNew = true;
        for (uint i = 0; i < persons[msg.sender].wardsAddress.length; i++) {
            if (wardAddress == persons[msg.sender].wardsAddress[i]) {
                isWardNew = false;
                break;
            }
        }
        require(isWardNew, "Ward is already added");
        
        persons[msg.sender].wardsAddress.push(wardAddress);
        
        Shared.Claim memory wardClaim;
        wardClaim.made = true;
        wardClaim.anyVerifier = true;
        wardClaim.numRequiredVerifiers = Shared.VERIFIERS_WARDS_CLAIM_COUNT;
        wardClaim.oldestDate = Shared.VERIFIERS_WARDS_CLAIM_OLDEST;
        persons[msg.sender].wardsClaim.push(wardClaim);
        
        emit wardAdded(wardAddress, msg.sender);
    }
    
    event wardRemoved(address ward, address person);
    function removeWard(address wardAddress) public onlyPerson {
        require(persons[msg.sender].wardsAddress.length > 0, "Patient must have a ward added already");
        
        for (uint i = 0; i < persons[msg.sender].wardsAddress.length; i++) {
            if (persons[msg.sender].wardsAddress[i] == wardAddress) {
                if (i < persons[msg.sender].wardsAddress.length) {
                    persons[msg.sender].wardsAddress[i] = persons[msg.sender].wardsAddress[persons[msg.sender].wardsAddress.length - 1];
                    persons[msg.sender].wardsClaim[i] = persons[msg.sender].wardsClaim[persons[msg.sender].wardsClaim.length - 1];
                }
                persons[msg.sender].wardsAddress.pop();
                persons[msg.sender].wardsClaim.pop();
                
                break;
            }
        }
        
        emit wardRemoved(wardAddress, msg.sender);
    }
    
    event wardVerified(address ward, address person);
    function verifyWard(address personAddress, address wardAddress) public onlyRAMember {
        require(persons[personAddress].guardiansAddress.length > 0, "Patient must have a ward added already");
        
        for (uint i = 0; i < persons[personAddress].wardsAddress.length; i++) {
            if (persons[personAddress].wardsAddress[i] == wardAddress) {
                Shared.verifyClaim(persons[personAddress].wardsClaim[i]);
            }
        }
        
        emit wardVerified(wardAddress, msg.sender);
    }
    
    
    // Adding medical documents functions
    event patientMDAdded(address p, bytes32 bh, uint nram, uint nguard);
    function addMDPatient(bytes32 bundleHash, uint defaultNumRAMVers, uint defaultNumGuardVers) public onlyPerson {
        require(Shared.isClaimVerified(persons[msg.sender].patientVerified), "Patient must be verified before adding a medical document");
        
        persons[msg.sender].bundleHashes.push(bundleHash);
        
        Shared.MedDoc memory md;
        md.exists = true;
        md.defaultNumRAMVers = Shared.between(defaultNumRAMVers, Shared.MIN_NUM_RA_VERS, Shared.MAX_NUM_RA_VERS);
        md.defaultNumGuardVers = Shared.between(defaultNumGuardVers, Shared.MIN_NUM_GUARD_VERS, Shared.MAX_NUM_GUARD_VERS);
        persons[msg.sender].meddocs[bundleHash] = md;
        
        emit patientMDAdded(msg.sender, bundleHash, md.defaultNumRAMVers, md.defaultNumGuardVers);
    }
    
    // TODO: function addMDWard() for a guardian to add a medical document for their ward after RAMember verification
    
    
    // Requesting medical documents functions
    event newMDRequest(address p, address d, bytes32 bh, uint rid);
    function requestMDDoctor(address patientAddress, bytes32 bundleHash, uint minRGTOCount, uint maxRGTOCount, bool direct) public {
        require(persons[patientAddress].meddocs[bundleHash].exists, "Requested medical document does not exist");
        require(minRGTOCount <= maxRGTOCount, "Request requires minimum count of RGTOs to be less than maximum count of RGTOs");
        
        Shared.Request memory request;
        request.exists = true;
        request.doctor = msg.sender;
        request.requestTime = now;
        request.minRGTOCount = Shared.max(minRGTOCount, Shared.MIN_RGTO_COUNT);
        request.maxRGTOCount = Shared.min(maxRGTOCount, Shared.MAX_RGTO_COUNT);
        
        Shared.Claim storage patientClaim;
        Shared.Claim memory ramemberClaim;
        Shared.Claim memory guardianClaim;
        if (direct) {
            patientClaim.made = true;
            patientClaim.anyVerifier = false;
            patientClaim.numRequiredVerifiers = 1;
            patientClaim.oldestDate = 7 days;
            patientClaim.requiredVerifiers.push(patientAddress);
            
        } else {
            ramemberClaim.made = true;
            ramemberClaim.anyVerifier = true;
            ramemberClaim.numRequiredVerifiers = persons[patientAddress].meddocs[bundleHash].defaultNumRAMVers;
            ramemberClaim.oldestDate = 3 days;
            
            guardianClaim.made = true;
            guardianClaim.anyVerifier = true; // not really, verifyRequestGuardian ensures only guardians of the patient can verify the claim
            guardianClaim.numRequiredVerifiers = persons[patientAddress].meddocs[bundleHash].defaultNumGuardVers;
            guardianClaim.oldestDate = 3 days;
        }
        
        request.patientVerifications = patientClaim;
        request.RAMemberVerifications = ramemberClaim;
        request.guardianVerifications = guardianClaim;
        request.rgtosEvaluated = false;
        
        persons[patientAddress].meddocs[bundleHash].requests[
            persons[patientAddress].meddocs[bundleHash].requestCount
            ] = request;
        persons[patientAddress].meddocs[bundleHash].requestCount += 1;
        
        emit newMDRequest(patientAddress, msg.sender, bundleHash, persons[patientAddress].meddocs[bundleHash].requestCount - 1);
    }
    
    
    // Responding to medical documents functions (patient + MPA)
    event patientVerifiedMDRequest(address p, address d, bytes32 bh, uint rid);
    function verifyRequestPatient(bytes32 bundleHash, uint requestId) public onlyPerson {
        require(persons[msg.sender].meddocs[bundleHash].requests[requestId].patientVerifications.made,
            "Patient verification was not asked for");
        
        Shared.verifyClaim(persons[msg.sender].meddocs[bundleHash].requests[requestId].patientVerifications);
        
        emit patientVerifiedMDRequest(msg.sender,
            persons[msg.sender].meddocs[bundleHash].requests[requestId].doctor, bundleHash, requestId);
    }
    
    event RAMVerifiedMDRequest(address p, address d, bytes32 bh, uint rid);
    function verifyRequestRAMember(address patientAddress, bytes32 bundleHash, uint requestId) public onlyRAMember {
        require(persons[patientAddress].meddocs[bundleHash].requests[requestId].RAMemberVerifications.made,
            "Regulatory agency member verification was not asked for");
        
        Shared.verifyClaim(persons[patientAddress].meddocs[bundleHash].requests[requestId].RAMemberVerifications);
        
        emit RAMVerifiedMDRequest(patientAddress,
            persons[msg.sender].meddocs[bundleHash].requests[requestId].doctor, bundleHash, requestId);
    }
    
    event guardianVerifiedMDRequest(address p, address d, bytes32 bh, uint rid);
    function verifyRequestGuardian(address patientAddress, bytes32 bundleHash, uint requestId) public onlyPerson {
        require(persons[patientAddress].meddocs[bundleHash].requests[requestId].guardianVerifications.made,
            "Guardian verification was not asked for");
        
        bool isValidGuardian = false;
        uint i;
        for (i = 0; i < persons[patientAddress].guardiansAddress.length; i++) {
            if (persons[patientAddress].guardiansAddress[i] == msg.sender) {
                if (Shared.isClaimVerified(persons[patientAddress].guardiansClaim[i])) {
                    isValidGuardian = true;
                }
                break;
            }
        }
        
        if (isValidGuardian) {
            Shared.verifyClaim(persons[patientAddress].meddocs[bundleHash].requests[requestId].guardianVerifications);
        }
        
        emit guardianVerifiedMDRequest(patientAddress,
            persons[msg.sender].meddocs[bundleHash].requests[requestId].doctor, bundleHash, requestId);
    }
    
    event callForRGTOs();
    function checkRequestStatus(address patientAddress, bytes32 bundleHash, uint requestId) public returns (bool) {
        if  (
            Shared.isClaimVerified(persons[patientAddress].meddocs[bundleHash].requests[requestId].patientVerifications) ||
            (
                Shared.isClaimVerified(persons[patientAddress].meddocs[bundleHash].requests[requestId].RAMemberVerifications) &&
                Shared.isClaimVerified(persons[patientAddress].meddocs[bundleHash].requests[requestId].guardianVerifications)
            )
            ) {
            
            if (!rgtos[msg.sender].registered) {
                emit callForRGTOs();
            }
            
            return true;
        }
        
        return false;
    }
    
    
    // RGTOs response functions
    function addRGTOResponse(address patientAddress, bytes32 bundleHash, uint requestId, bytes32 proof) public onlyRGTO {
        Shared.Request memory request = persons[patientAddress].meddocs[bundleHash].requests[requestId];
        
        // require(checkRequestStatus(patientAddress, bundleHash, requestId), "Granted request is required to call this function");
        require(!request.rgtosEvaluated, "Unevaluated request is required to call this function");
        
        uint16 latency = (uint16)(now - request.requestTime);
        
        // Conditions to accept new response
        if (request.rgtoAddresses.length < request.minRGTOCount ||
            (request.rgtoAddresses.length >= request.minRGTOCount &&
                request.rgtoAddresses.length < request.maxRGTOCount &&
                latency <= Shared.MAX_LATENCY)) {
                    
            uint8 isHashCorrect = (bundleHash == proof) ? 1 : 0;
            
            uint16 input_start = 1;
            uint16 input_end = uint16(1 hours);
            uint16 output_start = 2**16 - 1;
            uint16 output_end = 1;

            // TODO: make sure this is working correctly
            uint16 rgtoRating = isHashCorrect;
            if (latency < 1) {
                rgtoRating *= 2**16 - 1;
            } else if (latency > 1 hours) {
                rgtoRating *= 0; 
            } else {
                rgtoRating *=
                    output_start +
                    ((output_end - output_start) / (input_end - input_start)) *
                    (latency - input_start);
            }
            
            persons[patientAddress].meddocs[bundleHash].requests[requestId].rgtoAddresses.push(msg.sender);
            persons[patientAddress].meddocs[bundleHash].requests[requestId].rgtoRatings[msg.sender] = rgtoRating;
        }
        
        // Conditions to evaluate request
        if ((request.rgtoAddresses.length >= request.minRGTOCount &&
                request.requestTime + Shared.MAX_LATENCY <= now) ||
            request.rgtoAddresses.length == request.maxRGTOCount) {
                
            evaluateRGTOs(patientAddress, bundleHash, requestId);
            persons[patientAddress].meddocs[bundleHash].requests[requestId].rgtosEvaluated = true;
        }
    }
    
    
    // Evaluate RGTOs functions
    event tokenCreatedDoctor(bytes32 tokenID, address rgtoAddress);
    event tokenCreatedRGTO(bytes32 tokenID, address doctorAddress);
    function evaluateRGTOs(address patientAddress, bytes32 bundleHash, uint requestId) internal {
        Shared.Request storage request = persons[patientAddress].meddocs[bundleHash].requests[requestId];

        // uint16[] memory reputations = getOracleReputations(request.oracleAddresses);
        // uint16[] memory ratings = new uint16[](request.oracleAddresses.length);

        address bestRGTOAddress;
        uint64 bestRGTOScore = 0;

        for (uint i = 0; i < request.rgtoAddresses.length; i++) {
            uint16 rgtoRating = request.rgtoRatings[request.rgtoAddresses[i]];
            uint16 rgtoReputation = (rgtos[request.rgtoAddresses[i]].averageContractRating + rgtos[request.rgtoAddresses[i]].averageDoctorRating) / 2;

            uint64 rgtoScore = rgtoRating * (rgtoReputation + 1)**2;

            if (rgtoScore >= bestRGTOScore) {
                bestRGTOScore = rgtoScore;
                bestRGTOAddress = request.rgtoAddresses[i];
            }

            // ratings[i] = oracleRating;
        }

        for (uint16 i = 0; i < request.rgtoAddresses.length; i++) {
            Shared.RGTO memory rgto = rgtos[request.rgtoAddresses[i]];
            rgtos[request.rgtoAddresses[i]].averageContractRating = (rgto.contractRatingCount * rgto.averageContractRating + request.rgtoRatings[request.rgtoAddresses[i]]) / (rgto.contractRatingCount + 1);
            rgtos[request.rgtoAddresses[i]].contractRatingCount += 1;
        }

        bytes32 tokenID = keccak256(
            abi.encodePacked(request.doctor, bestRGTOAddress, now)
        );

        // emit tokenCreatedDoctor(tokenID, bestOracleAddress);
        // emit tokenCreatedOracle(tokenID, request.doctor);
        
        Shared.DOFileToken memory doFileToken;
        doFileToken.exists = true;
        doFileToken.rgtoAddress = bestRGTOAddress;
        persons[request.doctor].dofTokenIDs.push(tokenID);
        persons[request.doctor].dofTokens[tokenID] = doFileToken;
        
        Shared.ODFileToken memory odFileToken;
        odFileToken.exists = true;
        odFileToken.doctorAddress = request.doctor;
        rgtos[bestRGTOAddress].odfTokenIDs.push(tokenID);
        rgtos[bestRGTOAddress].odfTokens[tokenID] = odFileToken;
        
        emit tokenCreatedDoctor(tokenID, bestRGTOAddress);
        emit tokenCreatedRGTO(tokenID, request.doctor);
    }

    
    // TODO: think about the correct modifier here
    function submitDoctorRGTORating(bytes32 tokenID, address rgtoAddress, uint16 rating) public {
        require(rgtos[rgtoAddress].odfTokens[tokenID].exists &&
                persons[msg.sender].dofTokens[tokenID].exists,
                "Token does not exist");
                
        require(rgtos[rgtoAddress].odfTokens[tokenID].doctorAddress == msg.sender &&
                persons[msg.sender].dofTokens[tokenID].rgtoAddress == rgtoAddress,
                "Token is not valid");
        
        Shared.RGTO memory rgto = rgtos[rgtoAddress];
        rgtos[rgtoAddress].averageDoctorRating = (rgto.contractRatingCount * rgto.averageContractRating + rating) / (rgto.contractRatingCount + 1);
        rgtos[rgtoAddress].doctorRatingCount += 1;
    }
}