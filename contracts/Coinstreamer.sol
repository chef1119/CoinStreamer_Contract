// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract Coinstreamer is KeeperCompatibleInterface {

	uint256 public orderCounter; // the count of orders
  	address public keepersRegistry = address(0);

	struct SendInfo {
		address sender;
		address recipent;
		address tokenAddr;
		uint256 amount;
		uint256 duration;
		uint256 streams;
		uint256 streamCounter;
		uint256 lastTimeStamp;
		IERC20 token;
	}
	
	mapping(uint256 => SendInfo) public sendInfo; // Stores order informations (uint256) : index to loop by chainlink


	constructor(address _keepersRegistry) {
		keepersRegistry = _keepersRegistry;		//upkeeper rigistry
	}
// get bnb send order information from UI and update sendInfo
	function getBNB(address _recipent, uint256 _amount, uint256 _duration, uint256 _streams) external payable { 
		require(msg.value >= _amount, "Invalid amount!");

		SendInfo memory tempSendInfo = SendInfo({
			sender: msg.sender,
			recipent: _recipent,
			tokenAddr: address(0),
			amount: _amount,
			duration: _duration,
			streams: _streams,
			streamCounter: 0,
			lastTimeStamp: block.timestamp,
			token: IERC20(address(0))
		});

		sendInfo[orderCounter] = tempSendInfo;

		orderCounter = orderCounter + 1;
	}
// get token send order information from UI and update sendInfo
	function getToken(address _recipent, address _tokenAddr, uint256 _amount, uint256 _duration, uint256 _streams) external { 
		SendInfo memory tempSendInfo = SendInfo({
			sender: msg.sender,
			recipent: _recipent,
			tokenAddr: _tokenAddr,
			amount: _amount,
			duration: _duration,
			streams: _streams,
			streamCounter: 0,
			lastTimeStamp: block.timestamp,
			token: IERC20(_tokenAddr)
		});
		

		tempSendInfo.token.transferFrom(msg.sender, address(this), _amount);

		sendInfo[orderCounter] = tempSendInfo;
		orderCounter = orderCounter + 1;
	}
//can be called by chainlink, send ordered bnb or token when the condition is true
	function sendCoin(uint256 index) internal {
		uint256 _amount = sendInfo[index].amount / sendInfo[index].streams;
		if(sendInfo[index].tokenAddr == address(0)) {
			payable(sendInfo[index].recipent).transfer(_amount);
		}
		else {
			IERC20 tempToken;
			tempToken = IERC20(sendInfo[index].tokenAddr);
			tempToken.transfer(sendInfo[index].recipent, _amount);
		}
		sendInfo[index].lastTimeStamp = block.timestamp;
		sendInfo[index].streamCounter = sendInfo[index].streamCounter + 1;
	}

	modifier onlyKeepers() {
		require(msg.sender == keepersRegistry, "Ownable: caller is not keepers registry");
		_;
	}
//chainlink keeper automatically calls this function every 15 secs approximately
	function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
		for(uint256 index = 0; index < orderCounter; index = index +1) {
			upkeepNeeded = ((block.timestamp - sendInfo[index].lastTimeStamp) > (sendInfo[index].duration / sendInfo[index].streams)) && (sendInfo[index].streamCounter < sendInfo[index].streams);
		}
			// We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
	}
//chainlink keeper automatically calls this function when the condition(upkeepNeeded from above function) is true
	function performUpkeep(bytes calldata /* performData */) external override onlyKeepers {
			// We don't use the performData in this example. The performData is generated by the Keeper's call to your checkUpkeep function
		bool performCondition;
		for(uint256 index = 0; index < orderCounter; index = index +1) {
			performCondition = ((block.timestamp - sendInfo[index].lastTimeStamp) > (sendInfo[index].duration / sendInfo[index].streams)) && (sendInfo[index].streamCounter < sendInfo[index].streams);
			if(performCondition == true) sendCoin(index);
		}
	}
}