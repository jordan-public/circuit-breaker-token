// Configuration for different networks
const NETWORKS = {
    anvil: {
        chainId: 31337,
        name: 'Anvil Local',
        rpcUrl: 'http://127.0.0.1:8545',
        // These will be populated from the deployment
        contracts: {
            wbtc: '0xE53F8E8a492e85E87AE553AcFb676cEfF50740A6',
            cWBTC: '0x9112Fb7407f1E4818Cc394644E6165a74e5652A2',
            protocol: '0xD457436EBD456774E44F1Fa468D1D7423cFD9ddE'
        }
    },
    zircuit: {
        chainId: 48899,
        name: 'Zircuit Testnet',
        rpcUrl: 'https://zircuit1-testnet.p2pify.com',
        contracts: {
            wbtc: '', // Update after deployment
            cWBTC: '',
            protocol: ''
        }
    },
    rootstock: {
        chainId: 31,
        name: 'Rootstock Testnet',
        rpcUrl: 'https://rpc.testnet.rootstock.io/lZZVyJCscc9luAu3ByNcsjI9UOAb9H-T',
        contracts: {
            wbtc: '',
            cWBTC: '',
            protocol: ''
        }
    }
};

// ABIs for contract interaction
const ABIS = {
    MockWBTC: [
        {
            "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {"internalType": "address", "name": "spender", "type": "address"},
                {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "name": "approve",
            "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"internalType": "address", "name": "to", "type": "address"},
                {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "name": "mint",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        }
    ],
    CircuitBreakerToken: [
        {
            "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "uint256", "name": "amount", "type": "uint256"}],
            "name": "deposit",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "uint256", "name": "amount", "type": "uint256"}],
            "name": "withdraw",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"internalType": "address", "name": "spender", "type": "address"},
                {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "name": "approve",
            "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
            "name": "initiateLiquidation",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
            "name": "getLiquidatableAmount",
            "outputs": [
                {"internalType": "uint256", "name": "percentage", "type": "uint256"},
                {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "", "type": "address"}],
            "name": "liquidationBlockedUntil",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "", "type": "address"}],
            "name": "liquidationWindowEnd",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "", "type": "address"}],
            "name": "maxLiquidatableAmount",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "underlying",
            "outputs": [{"internalType": "address", "name": "", "type": "address"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "cooldownBlocks",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "liquidationWindow",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        }
    ],
    LendingProtocol: [
        {
            "inputs": [{"internalType": "address", "name": "", "type": "address"}],
            "name": "healthFactor",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "", "type": "address"}],
            "name": "userCollateral",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
            "name": "canLiquidate",
            "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
            "name": "getUserCollateral",
            "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {"internalType": "address", "name": "user", "type": "address"},
                {"internalType": "uint256", "name": "factor", "type": "uint256"}
            ],
            "name": "setHealthFactor",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"internalType": "address", "name": "user", "type": "address"},
                {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "name": "setCollateral",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "uint256", "name": "amount", "type": "uint256"}],
            "name": "depositCollateral",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
            "name": "initiateLiquidation",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"internalType": "address", "name": "user", "type": "address"},
                {"internalType": "address", "name": "liquidator", "type": "address"},
                {"internalType": "uint256", "name": "amount", "type": "uint256"}
            ],
            "name": "liquidate",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        }
    ]
};

// Export for use in app.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { NETWORKS, ABIS };
}
