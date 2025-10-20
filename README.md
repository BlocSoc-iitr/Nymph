# 🔐 Nymph - Anonymous Messaging Revolution

<div align="center">

*Where privacy meets performance in the world of anonymous communication*

</div>

---

## What is Nymph?

Nymph is a **next-generation anonymous messaging platform** that combines the power of **zero-knowledge proofs** with **blazing-fast native performance**. Think of it as your organization's private, anonymous social network where thoughts flow freely without identity concerns.

---

## 🚀 Key Features

### 🔑 **Zero-Knowledge Authentication**
- **Google OAuth Integration**: Seamless sign-in with your work account
- **Ephemeral Key Generation**: Temporary keys for maximum security
- **JWT Proof Generation**: Cryptographic proof of identity without revealing it

### 💬 **Anonymous Messaging**
- **Organization-Based Anonymity**: Post as "Someone from [YourOrg]"
- **Internal Channels**: Private discussions within your organization
- **Public Feed**: Share thoughts with the broader community
- **Markdown Support**: Rich text formatting for expressive communication

### ⚡ **Lightning-Fast Performance**
- **Native Execution**: Rust-powered cryptographic operations
- **Cross-Platform**: iOS and Android with shared codebase
- **Optimized Proofs**: Sub-second verification times

### 🛡️ **Advanced Security**
- **Proof Verification**: Anyone can verify message authenticity
- **Like System**: Anonymous engagement with cryptographic backing
- **Ephemeral Keys**: Temporary authentication for enhanced privacy
- **Organizational Isolation**: Seperate internal communication channels

---

## 🛠️ Development Setup

### Prerequisites
- **Rust** (latest stable)
- **Flutter** (3.0+)
- **Mopro CLI** (0.1.0)
- **iOS/Android** development environment

### Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Blocsoc-iitr/Nymph.git
   cd Nymph
   ```

2. **Install Mopro CLI**
   ```bash
   cargo install mopro-cli@0.1.0
   ```

3. **Build Native Bindings (if not already)**
   ```bash
   # For iOS
   mopro build  # Select: aarch64-apple-ios
   
   # For Android (enable android-compat in Cargo.toml first)
   mopro build  # Select: aarch64-linux-android
   ```

4. **Update Flutter Bindings**
   ```bash
   cp -r MoproiOSBindings flutter/mopro_flutter_plugin/ios && \
   cp -r MoproAndroidBindings/uniffi flutter/mopro_flutter_plugin/android/src/main/kotlin && \
   cp -r MoproAndroidBindings/jniLibs flutter/mopro_flutter_plugin/android/src/main
   ```

5. **Run the App**
   ```bash
   cd flutter
   flutter pub get
   flutter run
   ```

### 🔧 Configuration

#### Android Compatibility
Enable Android support in `Cargo.toml`:
```toml
noir = { git = "https://github.com/zkmopro/noir-rs", features = ["barretenberg", "android-compat"] }
```

#### Firebase Setup
1. Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
2. Configure Firebase Authentication
3. Set up your project's Firebase console

---

## 🔐 Security & Privacy

### Zero-Knowledge Architecture
- **No Identity Storage**: Your real identity is never stored
- **Ephemeral Keys**: Temporary authentication keys that expire
- **Proof-Based Verification**: Cryptographic proof of membership
- **Organizational Isolation**: Secure internal communication channels

### Data Protection
- **End-to-End Encryption**: All messages are encrypted in transit
- **No Metadata Collection**: We don't track your usage patterns
- **Local Key Management**: Keys stored securely on your device
- **Automatic Cleanup**: Ephemeral data is automatically purged

---

<div align="center">

*Empowering anonymous communication through zero-knowledge technology*

[![GitHub stars](https://img.shields.io/github/stars/blocsoc-iitr/nymph?style=social)](https://github.com/blocsoc-iitr/Nymph)
[![Twitter Follow](https://img.shields.io/twitter/follow/blocSocIITR?style=social)](https://twitter.com/blocSocIITR)

</div>