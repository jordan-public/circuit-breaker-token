// Global state
let web3;
let web3Read; // Separate instance for read operations to avoid rate limiting
let accounts;
let currentNetwork;
let contracts = {}; // For write operations (transactions)
let contractsRead = {}; // For read operations (calls)
let updateInterval;

// Initialize on page load
window.addEventListener('load', async () => {
    // Check if MetaMask is installed
    if (typeof window.ethereum !== 'undefined') {
        console.log('MetaMask is installed!');
    } else {
        showNotification('Please install MetaMask to use this dApp', 'error');
    }

    // Set up event listeners
    document.getElementById('connect-wallet').addEventListener('click', connectWallet);
    document.getElementById('disconnect-wallet').addEventListener('click', disconnectWallet);
    document.getElementById('create-loan').addEventListener('click', createLoan);
    document.getElementById('refresh-positions').addEventListener('click', refreshPositions);

    // Listen for account changes
    if (window.ethereum) {
        window.ethereum.on('accountsChanged', handleAccountsChanged);
        window.ethereum.on('chainChanged', handleChainChanged);
    }
});

// Connect wallet
async function connectWallet() {
    try {
        if (typeof window.ethereum === 'undefined') {
            showNotification('Please install MetaMask', 'error');
            return;
        }

        // Request account access
        accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        
        // Get network info from MetaMask first
        const tempWeb3 = new Web3(window.ethereum);
        const chainId = await tempWeb3.eth.getChainId();
        currentNetwork = Object.values(NETWORKS).find(n => n.chainId === chainId);
        
        if (!currentNetwork) {
            showNotification('Unsupported network. Switching to Anvil...', 'info');
            
            // Try to switch to Anvil network
            try {
                await window.ethereum.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: '0x7a69' }], // 31337 in hex
                });
                // Retry connection after switch
                return await connectWallet();
            } catch (switchError) {
                // Network doesn't exist, add it
                if (switchError.code === 4902) {
                    try {
                        await window.ethereum.request({
                            method: 'wallet_addEthereumChain',
                            params: [{
                                chainId: '0x7a69',
                                chainName: 'Anvil Local',
                                nativeCurrency: {
                                    name: 'Ethereum',
                                    symbol: 'ETH',
                                    decimals: 18
                                },
                                rpcUrls: ['http://127.0.0.1:8545'],
                            }]
                        });
                        showNotification('Anvil network added! Connecting...', 'success');
                        return await connectWallet();
                    } catch (addError) {
                        showNotification('Failed to add Anvil network', 'error');
                        return;
                    }
                }
                showNotification('Please connect to Anvil (localhost), Zircuit, or Rootstock', 'error');
                return;
            }
        }

        // Always use MetaMask provider for transactions
        web3 = new Web3(window.ethereum);
        
        // For Anvil, use direct RPC connection for read operations to avoid rate limiting
        if (currentNetwork.chainId === 31337) {
            web3Read = new Web3('http://127.0.0.1:8545');
        } else {
            web3Read = web3; // For testnets, use same provider
        }

        // Initialize contracts
        await initializeContracts();

        // Update UI
        document.getElementById('connect-wallet').style.display = 'none';
        document.getElementById('connected-wallet').style.display = 'flex';
        document.getElementById('wallet-address').textContent = formatAddress(accounts[0]);
        document.getElementById('network-info').style.display = 'flex';
        document.getElementById('network-name').textContent = currentNetwork.name;

        // Start updating block number
        startBlockUpdates();

        // Load positions
        await refreshPositions();

        showNotification('Wallet connected successfully!', 'success');
    } catch (error) {
        console.error('Error connecting wallet:', error);
        showNotification('Failed to connect wallet: ' + error.message, 'error');
    }
}

// Disconnect wallet
function disconnectWallet() {
    accounts = null;
    web3 = null;
    web3Read = null;
    contracts = {};
    contractsRead = {};
    
    if (updateInterval) {
        clearInterval(updateInterval);
    }

    document.getElementById('connect-wallet').style.display = 'block';
    document.getElementById('connected-wallet').style.display = 'none';
    document.getElementById('network-info').style.display = 'none';
    document.getElementById('positions-list').innerHTML = '<div class="loading"><p>Connect your wallet to view liquidatable positions</p></div>';
    
    showNotification('Wallet disconnected', 'info');
}

// Initialize contracts
async function initializeContracts() {
    const addresses = currentNetwork.contracts;
    
    // Write contracts (use MetaMask for transactions)
    contracts.wbtc = new web3.eth.Contract(ABIS.MockWBTC, addresses.wbtc);
    contracts.cWBTC = new web3.eth.Contract(ABIS.CircuitBreakerToken, addresses.cWBTC);
    contracts.protocol = new web3.eth.Contract(ABIS.LendingProtocol, addresses.protocol);
    
    // Read contracts (use direct RPC to avoid rate limiting)
    contractsRead.wbtc = new web3Read.eth.Contract(ABIS.MockWBTC, addresses.wbtc);
    contractsRead.cWBTC = new web3Read.eth.Contract(ABIS.CircuitBreakerToken, addresses.cWBTC);
    contractsRead.protocol = new web3Read.eth.Contract(ABIS.LendingProtocol, addresses.protocol);
}

// Create a test loan
async function createLoan() {
    if (!web3 || !accounts || !contracts.wbtc) {
        showNotification('Please connect your wallet first', 'error');
        return;
    }

    try {
        const collateralAmount = document.getElementById('collateral-amount').value;
        const healthFactor = document.getElementById('health-factor').value;

        if (!collateralAmount || !healthFactor) {
            showNotification('Please fill in all fields', 'error');
            return;
        }

        const amount = web3.utils.toWei(collateralAmount, 'ether');
        const healthFactorWei = web3.utils.toWei((healthFactor / 100).toString(), 'ether');

        showNotification('Creating loan position...', 'info');

        // 1. Mint WBTC (only works on local Anvil)
        if (currentNetwork.chainId === 31337) {
            await contracts.wbtc.methods.mint(accounts[0], amount).send({ from: accounts[0] });
        }

        // 2. Approve WBTC for cWBTC
        await contracts.wbtc.methods.approve(currentNetwork.contracts.cWBTC, amount)
            .send({ from: accounts[0] });

        // 3. Deposit to get cWBTC
        await contracts.cWBTC.methods.deposit(amount).send({ from: accounts[0] });

        // 4. Approve cWBTC for protocol
        await contracts.cWBTC.methods.approve(currentNetwork.contracts.protocol, amount)
            .send({ from: accounts[0] });

        // 5. Deposit collateral
        await contracts.protocol.methods.depositCollateral(amount).send({ from: accounts[0] });

        // 6. Set health factor
        await contracts.protocol.methods.setHealthFactor(accounts[0], healthFactorWei)
            .send({ from: accounts[0] });

        showNotification('Loan position created successfully!', 'success');
        
        // Refresh positions
        await refreshPositions();
    } catch (error) {
        console.error('Error creating loan:', error);
        showNotification('Failed to create loan: ' + error.message, 'error');
    }
}

// Refresh liquidatable positions
async function refreshPositions() {
    if (!web3 || !accounts || !contractsRead.protocol) {
        console.log('Wallet or contracts not initialized yet');
        return;
    }

    try {
        const positionsList = document.getElementById('positions-list');
        positionsList.innerHTML = '<div class="loading"><p>Loading positions...</p></div>';

        // For now, just show the current user's position
        // In a real app, you'd query events or maintain a list of positions
        const positions = [accounts[0]];

        if (positions.length === 0) {
            positionsList.innerHTML = '<div class="loading"><p>No liquidatable positions found</p></div>';
            return;
        }

        positionsList.innerHTML = '';
        
        for (const address of positions) {
            const positionCard = await createPositionCard(address);
            positionsList.appendChild(positionCard);
        }
    } catch (error) {
        console.error('Error refreshing positions:', error);
        showNotification('Failed to refresh positions: ' + error.message, 'error');
    }
}

// Create position card
async function createPositionCard(address) {
    const card = document.createElement('div');
    card.className = 'position-item';

    try {
        if (!contractsRead.protocol || !contractsRead.cWBTC) {
            throw new Error('Contracts not initialized');
        }

        // Get position data (use contractsRead to avoid rate limiting)
        const collateral = await contractsRead.protocol.methods.getUserCollateral(address).call();
        const healthFactor = await contractsRead.protocol.methods.healthFactor(address).call();
        const canLiquidate = await contractsRead.protocol.methods.canLiquidate(address).call();
        const liquidationData = await contractsRead.cWBTC.methods.getLiquidatableAmount(address).call();
        const currentBlock = await web3Read.eth.getBlockNumber();
        const blockedUntil = await contractsRead.cWBTC.methods.liquidationBlockedUntil(address).call();
        const windowEnd = await contractsRead.cWBTC.methods.liquidationWindowEnd(address).call();

        const collateralFormatted = web3.utils.fromWei(collateral, 'ether');
        const healthFactorPct = (parseInt(healthFactor) / 1e18 * 100).toFixed(1);
        const percentage = liquidationData.percentage;
        const liquidatableAmountWei = liquidationData.amount;
        const liquidatableAmount = web3.utils.fromWei(liquidationData.amount, 'ether');

        // Determine status
        let status = 'healthy';
        let statusText = 'Healthy';
        let statusClass = 'status-healthy';
        
        if (canLiquidate) {
            if (parseInt(blockedUntil) > 0) {
                if (currentBlock < parseInt(blockedUntil)) {
                    status = 'cooldown';
                    statusText = `Cooldown (${parseInt(blockedUntil) - currentBlock} blocks)`;
                    statusClass = 'status-cooldown';
                } else if (currentBlock <= parseInt(windowEnd)) {
                    status = 'window';
                    statusText = `Liquidation Window (${parseInt(windowEnd) - currentBlock} blocks left)`;
                    statusClass = 'status-window';
                } else {
                    status = 'expired';
                    statusText = 'Window Expired';
                    statusClass = 'status-liquidatable';
                }
            } else {
                status = 'liquidatable';
                statusText = 'Liquidatable';
                statusClass = 'status-liquidatable';
            }
        }

        card.innerHTML = `
            <div class="position-header">
                <div class="position-address">👤 ${formatAddress(address)}</div>
                <div class="status-badge ${statusClass}">${statusText}</div>
            </div>
            <div class="position-details">
                <div class="detail-item">
                    <span class="detail-label">Collateral</span>
                    <span class="detail-value">${parseFloat(collateralFormatted).toFixed(4)} cWBTC</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Health Factor</span>
                    <span class="detail-value">${healthFactorPct}%</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Liquidatable %</span>
                    <span class="detail-value">${percentage}%</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Liquidatable Amount</span>
                    <span class="detail-value">${parseFloat(liquidatableAmount).toFixed(4)} cWBTC</span>
                </div>
            </div>
            ${percentage > 0 ? `
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${percentage}%">${percentage}%</div>
                </div>
            ` : ''}
            <div class="liquidation-actions" id="actions-${address}">
                ${createActionButtons(address, status, canLiquidate, percentage, liquidatableAmount, liquidatableAmountWei)}
            </div>
        `;

        return card;
    } catch (error) {
        console.error('Error creating position card:', error);
        card.innerHTML = `<p>Error loading position data</p>`;
        return card;
    }
}

// Create action buttons based on position status
function createActionButtons(address, status, canLiquidate, percentage, amount, amountWei) {
    if (!canLiquidate) {
        return '<p class="info-text">Position is healthy - cannot be liquidated</p>';
    }

    if (status === 'liquidatable' || status === 'expired') {
        return `<button class="btn btn-warning" onclick="initiateLiquidation('${address}')">
            Initiate Liquidation
        </button>`;
    }

    if (status === 'cooldown') {
        return '<p class="info-text">⏳ In cooldown period - liquidation will be available soon</p>';
    }

    if (status === 'window' && parseInt(percentage) > 0) {
        return `<button class="btn btn-danger" onclick="executeLiquidation('${address}', '${amountWei}')">
            Liquidate ${percentage}% (${parseFloat(amount).toFixed(4)} cWBTC)
        </button>`;
    }

    return '<p class="info-text">No action available</p>';
}

// Initiate liquidation
async function initiateLiquidation(address) {
    try {
        showNotification('Initiating liquidation...', 'info');
        
        await contracts.protocol.methods.initiateLiquidation(address)
            .send({ from: accounts[0] });

        showNotification('Liquidation initiated! Cooldown period started.', 'success');
        
        // Refresh after a delay
        setTimeout(refreshPositions, 2000);
    } catch (error) {
        console.error('Error initiating liquidation:', error);
        showNotification('Failed to initiate liquidation: ' + error.message, 'error');
    }
}

// Execute liquidation
async function executeLiquidation(address, amountWei) {
    try {
        showNotification('Executing liquidation...', 'info');
        
        // Validate amount (already in wei)
        if (!amountWei || amountWei === '0' || parseInt(amountWei) === 0) {
            showNotification('Invalid liquidation amount', 'error');
            return;
        }
        
        console.log('Liquidating:', address, 'Amount (wei):', amountWei, 'Liquidator:', accounts[0]);
        
        await contracts.protocol.methods.liquidate(address, accounts[0], amountWei)
            .send({ from: accounts[0] });

        showNotification('Liquidation executed successfully!', 'success');
        
        // Refresh positions
        setTimeout(refreshPositions, 2000);
    } catch (error) {
        console.error('Error executing liquidation:', error);
        showNotification('Failed to execute liquidation: ' + error.message, 'error');
    }
}

// Start updating block number
function startBlockUpdates() {
    updateBlockNumber();
    updateInterval = setInterval(updateBlockNumber, 10000); // Poll every 10 seconds instead of 3
}

// Update block number
async function updateBlockNumber() {
    if (!web3Read) return;
    
    try {
        const blockNumber = await web3Read.eth.getBlockNumber();
        document.getElementById('current-block').textContent = blockNumber;
        
        // Don't auto-refresh positions to reduce RPC calls
        // User can click "Refresh Positions" button manually
    } catch (error) {
        console.error('Error updating block number:', error);
    }
}

// Handle account changes
function handleAccountsChanged(newAccounts) {
    if (newAccounts.length === 0) {
        disconnectWallet();
    } else {
        accounts = newAccounts;
        document.getElementById('wallet-address').textContent = formatAddress(accounts[0]);
        refreshPositions();
    }
}

// Handle chain changes
function handleChainChanged() {
    window.location.reload();
}

// Utility: Format address
function formatAddress(address) {
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
}

// Show notification
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 5000);
}
