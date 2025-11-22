# Slide 1: Title

# Circuit Breaker Token
## Progressive Liquidation Protection for DeFi

**Preventing Liquidation Storms Through Time-Delayed Execution**

---

# Slide 2: The Problem - Liquidation Storms

## Cascading Liquidations = Market Death Spirals

**Example:**
```
ETH = $2,000 → Small price drop to $1,980
→ 50 positions liquidated (500 ETH sold) → $1,940
→ 200 positions liquidated (2,000 ETH sold) → $1,860
→ 400 positions liquidated → $1,720
→ Cascade continues...
→ ETH crashes to $1,200 (40% drop!)
```

**The Real Issue:**
- Very few genuine sellers - mostly forced liquidations
- Natural buyers can't step in fast enough
- Technical failure mode, not a functioning market

---

# Slide 3: Individual User Problem

## Zero Time to React

**Current DeFi Lending:**
```
Block N:   Health Factor = 150% (Healthy)
Block N+1: Price drop → Health Factor = 95%
           INSTANT 100% LIQUIDATION
Block N+2: User's save transaction arrives (TOO LATE)
```

**Problems:**
- ❌ No response time for users
- ❌ MEV exploitation
- ❌ Flash crashes trigger permanent liquidations
- ❌ Users lose everything instantly

---

# Slide 4: Our Solution - Circuit Breaker

## Two-Phase Progressive Liquidation

**Phase 1: Cooldown (15 blocks = 15 seconds)**
- 0% liquidatable
- Users can add collateral
- Market can stabilize
- Price discovery at rational levels

**Phase 2: Progressive Window (15 blocks = 15 seconds)**
- Starts at 10% liquidatable
- Increases linearly to 100%
- Gradual approach prevents cascades

---

# Slide 5: Progressive Liquidation Curve

## 10% → 100% Over 15 Blocks

| Block | Liquidatable % | Example (50 cWBTC) |
|-------|---------------|-------------------|
| 0     | 10%           | 5.0 cWBTC         |
| 3     | 28%           | 14.0 cWBTC        |
| 7     | 46%           | 23.0 cWBTC        |
| 11    | 64%           | 32.0 cWBTC        |
| 15    | 100%          | 50.0 cWBTC        |

**Benefits:**
- Multiple chances to save position
- Minimal market impact
- Fair to all parties

---

# Slide 6: Wallet Balance Protection

## Grace Period for Users with Available Funds

**Time-Decaying Cap System:**

If user has ≥100% wallet balance: **50% starting cap**
If user has ≥50% wallet balance: **70% starting cap**

Cap increases from base → 100% over window

**Example: User with 120% wallet balance**
- Block 0: Only 10% liquidatable (capped at 50%)
- Block 7: 46% liquidatable (cap now 70%)
- Block 15: 100% liquidatable (cap expired)

**Incentivizes action while providing protection**

---

# Slide 7: Why Wrapped Tokens?

## Works with EVERY Lending Protocol

**Major Protocols (Aave, Compound, Maker):**
- ❌ Billions in TVL - cannot modify
- ❌ Governance takes months/years
- ❌ Risk breaking integrations
- ❌ Extensive audits required

**Our Approach: Universal Wrapper Tokens ✅**
- cWBTC, cUSDC, cDAI wrap existing tokens
- **Works with ANY protocol** that accepts ERC20 collateral
- No protocol changes needed - just add as collateral
- Users opt-in by choice
- Protocol-agnostic design

---

# Slide 8: Deployment Options

## Ready for Immediate Use on ANY Protocol

**Permissionless Protocols (Deploy Today):**
- ✅ Morpho, Euler V2, Silo Finance
- ✅ Elara & Purrlend (Zircuit testnet)
- ✅ Lambdalend

**DAO-Governed (Governance Vote Needed):**
- 📋 Aave V3, Compound V3, Maker
- 📋 Timeline: Weeks to months

**Universal Compatibility:**
- Works with ANY lending protocol that accepts ERC20s
- No protocol modifications required
- Just add cWBTC, cUSDC, cDAI as collateral tokens

---

# Slide 9: Trade-offs & Economics

## Balanced Design

**Cost:**
- +0.5-1% higher APR on borrowing
- Compensation for delayed liquidation risk
- Think of it as liquidation cascade insurance

**Benefits:**
- 🛡️ Protection from instant liquidation
- 🛡️ Time to save your position
- 🛡️ Market stability during volatility
- 🛡️ Prevents 20-40% cascade crashes

**Fair to everyone:** Users, Protocols, and Liquidators

---

# Slide 10: Contact & Links

## Get Involved

**GitHub:** github.com/jordan-public/circuit-breaker-token

**Demo:** Live UI demonstration available in `/demo` folder

**Technology Stack:**
- Solidity 0.8.20
- Foundry framework
- Web3.js frontend
- Deployed on Anvil, Zircuit, Rootstock

**Contact:** [Your contact information]

**Built for:** ETHGlobal Bangkok 2024
