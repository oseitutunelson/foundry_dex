// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Decentralized Exchange
 * @author Owusu Nelson Osei Tutu
 * @notice A decentralized exhange smart contract
 */

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DEX {
    using SafeERC20 for ERC20;

    //events
    event OrderPlaced(
        uint256 orderId, address indexed trader, address indexed token, uint256 tokenTotal, uint256 etherAmount
    );
    event OrderFilled(uint256 orderId, address indexed trader, uint256 tokensFilled, uint256 etherTransferred);

    //state variables
    address public owner;
    Order[] public openOrders;
    Liquidity[] public liquidityPool;
    //token structure

    struct Token {
        ERC20 tokenContract;
        uint256 totalLiquidity;
    }
    // liquidity structure

    struct Liquidity {
        address provider;
        ERC20 token;
        uint256 tokenAmount;
        uint256 etherAmount;
    }

    //order structure
    struct Order {
        address trader;
        address token;
        uint256 tokenTotal;
        uint256 tokenLeft;
        uint256 etherAmount;
        uint256 filled;
    }

    //mappings
    mapping(address => Token) public tokens; //address to token
    mapping(address => mapping(address => uint256)) public tokenBalances; //address User -> address token -> token balance
    mapping(address => mapping(address => uint256)) public etherBalances; //address User -> address token -> ether balance
    mapping(address => Order[]) public orderHistories; //order history

    //modifiers
    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }

    //functions
    constructor() {
        owner = msg.sender;
    }

    //add tokens
    function addToken(address tokenAddress) public onlyOwner {
        ERC20 token = ERC20(tokenAddress);
        tokens[tokenAddress] = Token({tokenContract: token, totalLiquidity: 0});
    }

    //deposit tokens
    function depositToken(address tokenAddress, uint256 amount) public {
        require(tokens[tokenAddress].tokenContract != ERC20(address(0)), "Token not supported by dex");
        require(tokenAddress != address(0), "Cannot deposit to zero address");
        tokens[tokenAddress].tokenContract.safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[msg.sender][tokenAddress] += amount;
    }

    //deposit eth
    function deposit() public payable {
        require(msg.value > 0);
        tokenBalances[msg.sender][address(0)] += msg.value; //Eth is stored as zero address
        etherBalances[msg.sender][address(0)] += msg.value;
    }

    //withdraw tokens
    function withdrawTokens(address tokenAddress, uint256 amount) public {
        require(tokens[tokenAddress].tokenContract != ERC20(address(0)), "Token not supported by dex");
        require(tokenAddress != address(0), "Cannot deposit to zero address");
        tokenBalances[msg.sender][tokenAddress] -= amount;
        tokens[tokenAddress].tokenContract.safeTransfer(msg.sender, amount);
    }

    //withdraw eth
    function withdraw(uint256 amount) public {
        require(etherBalances[msg.sender][address(0)] >= amount, "Insufficient ether balance.");
        etherBalances[msg.sender][address(0)] -= amount;
        payable(msg.sender).transfer(amount);
    }

    //place order
    function placeOrder(address token, uint256 tokensTotal, uint256 etherAmount) public {
        require(tokens[token].tokenContract != ERC20(address(0)));
        require(tokenBalances[msg.sender][token] >= tokensTotal);

        //place the order
        Order memory newOrder = Order({
            trader: msg.sender,
            token: token,
            tokenTotal: tokensTotal,
            tokenLeft: tokensTotal,
            etherAmount: etherAmount,
            filled: 0
        });

        openOrders.push(newOrder);
        tokenBalances[msg.sender][token] -= tokensTotal;

        emit OrderPlaced(openOrders.length - 1, msg.sender, token, tokensTotal, etherAmount);
    }

    //fill order

    function fillOrder(uint256 orderId) public {
        Order storage order = openOrders[orderId];
        uint256 tokensToFill = order.tokenLeft;
        uint256 etherToFill = (tokensToFill * order.etherAmount) / order.tokenTotal;

        require(etherBalances[msg.sender][address(0)] >= etherToFill, "Insufficient ether balance.");

        etherBalances[order.trader][address(0)] += etherToFill;
        etherBalances[msg.sender][address(0)] -= etherToFill;
        tokenBalances[msg.sender][order.token] += tokensToFill;
        order.tokenLeft = 0;
        order.filled += tokensToFill;

        orderHistories[msg.sender].push(order);
        if (order.trader != msg.sender) orderHistories[order.trader].push(order);
        delete openOrders[orderId];

        emit OrderFilled(orderId, order.trader, tokensToFill, etherToFill);
    }

    // add liquidity
    function addLiquidity(address token, uint256 tokenAmount, uint256 etherAmount) public {
        require(tokens[token].tokenContract != ERC20(address(0)), "Token not supported by dex");
        require(tokenBalances[msg.sender][token] >= tokenAmount, "Insufficient token balance");

        tokens[token].tokenContract.safeTransferFrom(msg.sender, address(this), tokenAmount);
        tokenBalances[msg.sender][token] -= tokenAmount;

        etherBalances[msg.sender][address(0)] += etherAmount;
        tokenBalances[msg.sender][address(0)] += etherAmount; // Ether is stored as zero address

        liquidityPool.push(
            Liquidity({
                provider: msg.sender,
                token: tokens[token].tokenContract,
                tokenAmount: tokenAmount,
                etherAmount: etherAmount
            })
        );
    }
}
