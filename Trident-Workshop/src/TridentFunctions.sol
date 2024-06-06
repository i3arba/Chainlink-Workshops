//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/////////////
///Imports///
/////////////
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";


//////////////
/// ERRORS ///
//////////////
error TridentFunctions_UnexpectedRequestID(bytes32 requestId);
error TridentFunctions_EmptyArgs();
error TridentFunctions_CallerNotAllowed();

contract TridentFunctions is FunctionsClient{
    using FunctionsRequest for FunctionsRequest.Request;

    ///////////////////////
    ///Type declarations///
    ///////////////////////
    ///@notice 
    struct FunctionsResponse{
        bytes lastResponse;
        bytes lastError;
        bool exists;
    }

    ///@notice 
    struct GameScore{
        bytes lastResponse;
        bytes lastError;
        bool exists;
        string name;
        uint256 score;
    }
    
    /////////////
    ///Storage///
    /////////////
    ///@notice 
    mapping(bytes32 requestId => FunctionsResponse) private s_responses;
    ///@notice 
    mapping(bytes32 requestId => GameScore) private s_responsesGet;
    ///@notice mapping to keep track of game score avaliation
    mapping(string gameName => uint256[]) public s_dailyAvaliation;

    ///////////////
    ///CONSTANTS///
    ///////////////
    ///@notice 
    uint256 private constant ONE = 1;
    ///@notice 
    uint32 private constant GAS_LIMIT = 300_000;    
    ///@notice 
    string private constant SOURCE_GET =
        "const gameName = args[0];"
        "const response = await Functions.makeHttpRequest({"
        "url: `http://64.227.122.74:3000/score/name/${gameName}`," //https://bellumgalaxy.xyz/score
        "method: 'GET',"
        "});"
        "if (response.error) {"
        "  throw Error(`Request failed message ${response.message}`);"
        "}"
        "const { data } = response;"
        "return Functions.encodeUint256(data.score);"
    ;

    ////////////////
    ///IMMUTABLES///
    ////////////////
    ///@notice 
    bytes32 private immutable i_donID;
    ///@notice 
    uint64 private immutable i_subscriptionId;

    ////////////
    ///Events///
    ////////////
    ///@notice 
    event TridentFunctions_Response(bytes32 indexed requestId, bytes response, bytes err);

    ///////////////
    ///Modifiers///
    ///////////////

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////////////Functions////////////////////////////////
    /////////////////////////////////////////////////////////////////////////

    /////////////////
    ///constructor///
    /////////////////
    /**
     * 
     * @param _router Chainlink Functions Router Address
     * @param _donId Chainlink Functions DonId
     * @param _subId Chainlink Functions Subscription Id
     */
    constructor(address _router, bytes32 _donId, uint64 _subId) FunctionsClient(_router) {
        i_donID = _donId;
        i_subscriptionId = _subId;
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param _args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequestToGet(string[] memory _args) external  returns(bytes32 requestId) {
        if(_args.length < ONE) revert TridentFunctions_EmptyArgs();

        FunctionsRequest.Request memory req;
        // Initialize the request with JS code
        req.initializeRequestForInlineJavaScript(SOURCE_GET);

        // Set the arguments for the request
        req.setArgs(_args);

        // Send the request and store the request ID
        requestId = _sendRequest(
            req.encodeCBOR(),
            i_subscriptionId,
            GAS_LIMIT,
            i_donID
        );

        s_responsesGet[requestId] = GameScore({
            lastResponse: "",
            lastError: "",
            exists: true,
            name: _args[0],
            score: 0
        });
    }

    function getScoreDailyHistory(string memory _name) external view returns(uint256[] memory score){
        score = s_dailyAvaliation[_name];
    }
    
    //////////////
    ///internal///
    //////////////
    /**
     * @notice Callback function for fulfilling a request
     * @param _requestId The ID of the request to fulfill
     * @param _response The HTTP response data
     * @param _err Any errors from the Functions request
    */
    function fulfillRequest(bytes32 _requestId, bytes memory _response, bytes memory _err) internal override {
        if (s_responsesGet[_requestId].exists == false) revert TridentFunctions_UnexpectedRequestID(_requestId);
        
        GameScore storage score = s_responsesGet[_requestId];
   
        uint256 scoreNow = abi.decode(_response, (uint256));
        score.lastResponse = _response;
        score.lastError = _err;
        score.score = scoreNow;
        s_dailyAvaliation[score.name].push(scoreNow);

        emit TridentFunctions_Response(_requestId, _response, _err);
    }
    /////////////
    ///private///
    /////////////

    /////////////////
    ///view & pure///
    /////////////////
}