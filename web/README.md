# Circuit Breaker Token - Web Interface

A web-based dashboard for interacting with the Circuit Breaker Token liquidation system.

## Features

- 🔗 **Wallet Connection**: Connect with MetaMask to interact with the protocol
- 💰 **Create Loans**: Create test loan positions with customizable collateral and health factors
- 🎯 **View Liquidatable Positions**: See all positions eligible for liquidation
- ⏱️ **Real-time Updates**: Track cooldown periods and liquidation windows
- 📊 **Progressive Liquidation**: Visual representation of liquidatable percentages
- 🔄 **Execute Liquidations**: Initiate and execute liquidations through the UI

## How to Use

### 1. Prerequisites

- MetaMask browser extension installed
- Connection to one of the supported networks:
  - Anvil (Local): `http://127.0.0.1:8545` (chainId: 31337)
  - Zircuit Testnet (chainId: 48899)
  - Rootstock Testnet (chainId: 31)

### 2. Setup for Local Testing (Anvil)

1. Start Anvil in one terminal:
   ```bash
   cd /Users/jordan/circuit-breaker-token
   ./anvil.sh
   ```

2. Deploy contracts in another terminal:
   ```bash
   ./deployAnvil.sh
   ```

3. Update `config.js` with deployed contract addresses (if different from defaults)

4. Serve the web interface:
   ```bash
   cd web
   python3 -m http.server 8000
   # OR
   npx serve
   ```

5. Open your browser to `http://localhost:8000`

### 3. Connect MetaMask to Anvil

1. Open MetaMask
2. Click on the network dropdown
3. Click "Add Network" → "Add a network manually"
4. Enter the following details:
   - Network Name: `Anvil Local`
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`
   - Currency Symbol: `ETH`
5. Import an Anvil test account using one of the private keys from anvil output

### 4. Using the Interface

#### Create a Test Loan
1. Click "Connect Wallet" and approve the connection
2. Enter collateral amount (e.g., 50 cWBTC)
3. Enter health factor (e.g., 80% for liquidatable position)
4. Click "Create Loan Position"
5. Approve the transactions in MetaMask

#### Initiate Liquidation
1. View the position in "Liquidatable Positions" section
2. When position shows "Liquidatable" status, click "Initiate Liquidation"
3. Approve the transaction
4. Position enters cooldown period (15 blocks)

#### Execute Liquidation
1. After cooldown, the liquidation window opens (15 blocks)
2. The interface shows the current liquidatable percentage (10% → 100%)
3. Click the liquidation button showing percentage and amount
4. Approve the transaction to seize the collateral

## Understanding the UI

### Position Status Badges

- **🟢 Healthy**: Health factor > 100%, cannot be liquidated
- **🔴 Liquidatable**: Health factor < 100%, can initiate liquidation
- **🟡 Cooldown**: Liquidation initiated, waiting for cooldown to end
- **🔵 Liquidation Window**: Active window, can execute partial liquidation

### Progressive Liquidation Visualization

The progress bar shows how much of the position can be liquidated:
- **10%** at start of window
- Increases linearly over 15 blocks
- **100%** at end of window

Actual percentage may be capped based on user's wallet balance.

## Configuration

Edit `config.js` to update:
- Contract addresses for different networks
- RPC URLs
- Chain IDs

## Network-Specific Notes

### Anvil (Local)
- Full control over minting tokens
- Can create test positions easily
- Fast block times for testing

### Zircuit Testnet
- Need testnet WBTC
- Update contract addresses after deployment
- Use deployment script: `./deployZircuit.sh`

### Rootstock Testnet
- Need testnet RBTC for gas
- Bitcoin-focused testing
- Use deployment script: `./deployRootstock.sh`

## Troubleshooting

### "Please install MetaMask"
Install the MetaMask browser extension from metamask.io

### "Please connect to Anvil..."
Make sure you're connected to the correct network in MetaMask

### "Failed to connect wallet"
- Check that Anvil is running (for local testing)
- Verify the RPC URL in MetaMask matches the network
- Ensure you have an account with ETH for gas

### Transactions Failing
- Make sure contracts are deployed to the connected network
- Check that contract addresses in `config.js` match deployments
- Verify you have sufficient balance for gas fees

## Development

The web interface consists of:
- `index.html`: Main HTML structure
- `styles.css`: Styling and responsive design
- `config.js`: Network and contract configuration
- `app.js`: Web3 integration and business logic

To modify:
1. Edit the files
2. Refresh the browser (no build step required)
3. Test with local Anvil before deploying to testnets

## Future Enhancements

- [ ] Support for multiple user positions
- [ ] Historical liquidation events viewer
- [ ] Charts showing liquidation curve over time
- [ ] Wallet balance detection and cap visualization
- [ ] Batch liquidation support
- [ ] Mobile-responsive improvements
