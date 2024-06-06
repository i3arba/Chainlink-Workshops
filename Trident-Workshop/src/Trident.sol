// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TridentNFT} from "./TridentNFT.sol";
import {TridentFunctions} from "./TridentFunctions.sol";

//////////////
/// ERRORS ///
//////////////
///@notice emitted when publisher tries to deploy duplicate game
error Trident_InvalidGameSymbolOrName(string symbol, string name);
///@notice emitted when there is no game to check for score
error Trident_GameNotCreatedYet();
///@notice emitted when an user don't have enough balance
error Trident_NotEnoughBalance(uint256 gamePrice);
///@notice emitted when the selling period is not open yet
error Trident_GameNotAvailableYet(uint256 timeNow, uint256 releaseTime);

/**
    *@author Barba - Chainlink Advocate
    *@title Pato Branco Workshop - Trident Project
    *@dev This is a simplified version of Trident Project from Block Magic Hackathon
    *@dev this codebase was intentionally made unsafe by removing checks and control accesses.
    *@dev do not use in production
    *@custom:contact www.bellumgalaxy.com - https://linktr.ee/bellumgalaxy
*/
contract Trident{
    using SafeERC20 for ERC20;
    
    ////////////////////
    /// CUSTOM TYPES ///
    ////////////////////
    ///@notice Struct to track new games NFTs
    struct GameRelease{
        string gameSymbol;
        string gameName;
        TridentNFT keyAddress;
        uint256 sellingDate;
        uint256 price;
        uint256 copiesSold;
    }

    ///@notice Struct to track buying info.
    struct ClientRecord {
        string gameName;
        TridentNFT game;
        uint256 buyingDate;
        uint256 paidValue;
    }

    //////////////////////////////
    /// CONSTANTS & IMMUTABLES ///
    //////////////////////////////
    ///@notice magic number removal
    uint256 private constant ZERO = 0;
    ///@notice magic number removal
    uint256 private constant ONE = 1;
    ///@notice magic number removal
    uint256 private constant DECIMALS = 10**18;

    ///@notice functions constract instance
    TridentFunctions private immutable i_functions;

    ///////////////////////
    /// STATE VARIABLES ///
    ///////////////////////
    uint256 private s_gameIdCounter;
    string[] private scoreCheck;

    ///@notice Mapping to keep track of future launched games
    mapping(uint256 gameIdCounter => GameRelease) private s_gamesCreated;
    ///@notice Mapping to keep track of games an user has
    mapping(address client => ClientRecord[]) private s_clientRecords;
    ///@notice Mapping to keep track of CCIP transactions

    //////////////
    /// EVENTS ///
    //////////////
    ///@notice event emitted when a new game nft is created
    event Trident_NewGameCreated(uint256 gameId, string tokenSymbol, string gameName, TridentNFT tridentNFT);
    ///@notice event emitted when a new copy is sold.
    event Trident_NewGameSold(uint256 gameId, string gameName, address payer, uint256 date, address gameReceiver);

    /////////////////
    ///CONSTRUCTOR///
    /////////////////
    constructor(TridentFunctions _functionsAddress){
        i_functions = _functionsAddress;
    }

    /////////////////////////////////////////////////////////////////
    /////////////////////////// FUNCTIONS ///////////////////////////
    /////////////////////////////////////////////////////////////////

    ////////////////////////////////////
    /// EXTERNAL onlyOwner FUNCTIONS ///
    ////////////////////////////////////

    /**
        *@notice Function for Publisher to create a new game NFT
        *@param _gameSymbol game's identifier
        *@param _gameName game's name
        *@dev we deploy a new NFT key everytime a game is created.
    */
    function createNewGame(string memory _gameSymbol, string memory _gameName, uint256 _startingDate, uint256 _price) external {
        // CHECKS
        if(bytes(_gameSymbol).length < ONE || bytes(_gameName).length < ONE) revert Trident_InvalidGameSymbolOrName(_gameSymbol, _gameName);

        s_gameIdCounter = s_gameIdCounter + ONE;

        //EFFECTS
        s_gamesCreated[s_gameIdCounter] = GameRelease({
            gameSymbol:_gameSymbol,
            gameName: _gameName,
            keyAddress: TridentNFT(address(0)),
            sellingDate: _startingDate,
            price: _price * DECIMALS,
            copiesSold: 0
        });

        scoreCheck.push(_gameName);

        emit Trident_NewGameCreated(s_gameIdCounter, _gameSymbol, _gameName, s_gamesCreated[s_gameIdCounter].keyAddress);

        s_gamesCreated[s_gameIdCounter].keyAddress = new TridentNFT();
    }

    /**
     * @notice function to request AI information about games created.
     */
    function gameScoreGetter() external {
        uint256 gamesNumber = scoreCheck.length;

        if(gamesNumber < ONE) revert Trident_GameNotCreatedYet();

        for(uint256 i; i < gamesNumber; ++i){
            string[] memory args = new string[](1);

            args[0] = scoreCheck[i];

            i_functions.sendRequestToGet(args);
        }
    }

    //////////////////////////
    /// EXTERNAL FUNCTIONS ///
    //////////////////////////
    /**
        * @notice Function for users to buy games
        * @param _gameId game identifier
        * @param _chosenToken token used to pay for the game
        *@dev _gameSymbol param it's an easier explanation option.
    */
    function buyGame(uint256 _gameId, ERC20 _chosenToken, address _gameReceiver) external {        
        GameRelease memory gameNft = s_gamesCreated[_gameId];

        if(block.timestamp < gameNft.sellingDate) revert Trident_GameNotAvailableYet(block.timestamp, gameNft.sellingDate);

        if(_chosenToken.balanceOf(msg.sender) < gameNft.price ) revert Trident_NotEnoughBalance(gameNft.price);

        address buyer = msg.sender;

        _handleExternalCall(_gameId, gameNft.keyAddress, block.timestamp, gameNft.price, buyer, _gameReceiver, _chosenToken);
    }

    /////////////
    ///PRIVATE///
    /////////////
    /**
     * @notice function to deal with storage update and external call's
     * @param _gameId the ID of the buyed game
     * @param _keyAddress the game's contract address
     * @param _buyingDate the date of buying
     * @param _value the value to be paid
     * @param _buyer the user that is buying
     * @param _gameReceiver the address that will receive the game
     * @param _chosenToken the token to pay.
     */
    function _handleExternalCall(uint256 _gameId,
                                 TridentNFT _keyAddress,
                                 uint256 _buyingDate,
                                 uint256 _value,
                                 address _buyer,
                                 address _gameReceiver,
                                 ERC20 _chosenToken) private {

        GameRelease memory gameNft = s_gamesCreated[_gameId];

        //EFFECTS
        ClientRecord memory newGame = ClientRecord({
            gameName: gameNft.gameName,
            game: _keyAddress,
            buyingDate: _buyingDate,
            paidValue: _value
        });

        s_clientRecords[_gameReceiver].push(newGame);
        ++s_gamesCreated[_gameId].copiesSold;

        emit Trident_NewGameSold(_gameId, gameNft.gameName, _buyer, _buyingDate, _gameReceiver);

        //INTERACTIONS
        _chosenToken.safeTransferFrom(_buyer, address(this), _value);
        gameNft.keyAddress.safeMint(_gameReceiver);
    }

    /////////////////
    ///VIEW & PURE///
    /////////////////

    /**
     * @notice function to get about game creation
     * @param _gameId the game id
     */
    function getGamesCreated(uint256 _gameId) external view returns(GameRelease memory){
        return s_gamesCreated[_gameId];
    }

    /**
     * @notice Function to get client infos
     * @param _client the address of the client
     */
    function getClientRecords(address _client) external view returns(ClientRecord[] memory){
        return s_clientRecords[_client];
    }

    function getScoreChecker() external view returns(string[] memory){
        return scoreCheck;
    }
}
