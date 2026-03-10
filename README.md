# Scrapekia: Enterprise Logistics & Fleet Management System ♻️

[![Flutter](https://img.shields.io/badge/Flutter-3.10.7+-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Riverpod](https://img.shields.io/badge/State--Management-Riverpod-02569B?logo=riverpod&logoColor=white)](https://riverpod.dev/)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![Architecture](https://img.shields.io/badge/Architecture-Feature--First-orange)](#system-architecture)

**Scrapekia** is a high-performance, production-grade logistics application designed for a real-world scrap collection enterprise. It manages the full lifecycle of scrap retrieval—from customer order placement and administrative fleet oversight to real-time worker dispatch and route optimization.

---

## 🏗️ Professional Project Overview

Scrapekia is engineered as a robust, scalable solution for the "last-mile" scrap collection industry. Unlike simple CRUD applications, this system handles complex state synchronization across multiple user roles (Admins and Field Workers) and integrates deep mapping logic to solve physical logistics challenges. It prioritizes reliability and offline resilience, ensuring that field operations continue even in areas with poor network coverage.

## ⚠️ Problem Statement

In the scrap collection industry, manual coordination leads to significant inefficiencies:

- **Operation Latency**: Delays in assigning pickup requests to available field workers.
- **Suboptimal Logistics**: High fuel costs and time wastage due to disorganized routing.
- **Data Silos**: Difficulty tracking financial transactions and worker performance across the fleet.
- **Resiliency Gaps**: Field workers losing access to critical order data in dead zones.

**Scrapekia addresses these by providing a real-time, geolocated, and offline-capable dashboard that optimizes fleet movement and automates order prioritization.**

---

## ✨ Key Features

- **🔄 Real-Time Synchronization**: Leverages Supabase real-time subscriptions and Riverpod reactive state to ensure all stakeholders see order status updates instantly.
- **🛠️ Intelligent Dispatch System**: RPC-driven worker assignment logic prevents race conditions during order claims.
- **📈 Automated Priority Bumping**: A server-side/client-side hybrid logic that elevates order urgency (Normal → Medium → Urgent) automatically based on elapsed time.
- **👥 Role-Based Access Control (RBAC)**: Secure access management using Supabase Row Level Security (RLS) to separate administrative telemetry from worker-specific field data.
- **💰 Financial Transparency**: Built-in transaction logging and service price lists to standardize collection costs and payments.

---

## 🏛️ System Architecture

Scrapekia utilizes a **Feature-First Modular Architecture**, promoting strict separation of concerns and high testability.

### Architectural Layers:

1.  **Presentation Layer**: Decoupled UI using Riverpod `Notifier` and `StateNotifier`. This ensures that business logic is completely separated from the widget tree.
2.  **Domain Layer**: Feature-specific models (Orders, Users, MapData) that represent the business state.
3.  **Data Layer**: Centralized repositories managing Supabase interactions, Hive local caching, and secure storage for sensitive credentials.
4.  **Service Layer**: Singleton-style services for GPS tracking, OSRM routing, and network connectivity monitoring.

### Why Riverpod?

Riverpod was chosen for its compile-time safety and ability to handle complex provider dependencies. During development, we optimized the logout flow to handle recursive provider invalidations, ensuring a clean state reset across all modules without circular dependency exceptions.

---

## 🗺️ Map & Location System

The heart of the application is a sophisticated mapping engine:

- **Offline Resilience**: Uses **MBTiles (sqlite3)** to store and render map tiles locally, ensuring functionality without internet.
- **Route Optimization**: Integrates **OSRM (Open Source Routing Machine)** for real-time road-distance calculations rather than simple "as-the-crow-flies" distance.
- **Dynamic Proximity Sorting**: field workers see orders sorted by actual road distance from their current GPS coordinates.
- **Edge Indicators**: A custom UI implementation that points to off-screen markers, helping workers maintain spatial awareness of their surrounding assignments.

---

## 🛠️ Tech Stack

- **Frontend**: Flutter SDK (3.10.7+), Material 3
- **State Management**: flutter_riverpod, state_notifier
- **Database (Cloud)**: PostgreSQL via Supabase
- **Database (Local)**: Hive CE (High-performance NoSQL), SharedPreferences
- **Mapping**: flutter_map, latlong2, OSRM API, mbtiles
- **Security**: Supabase Auth, flutter_secure_storage, BCrypt
- **UI/UX**: Lottie, Shimmer AI, Google Fonts (Cairo)

---

## 🔐 Security & Authentication

- **Identity Management**: Secure phone-to-email masking for private user authentication.
- **Data Privacy**: RLS policies ensure workers only access assigned data, while admins maintain full visibility.
- **Credential Storage**: Sensitive tokens are managed via `flutter_secure_storage` using platform-specific encryption (Keychain for iOS, Keystore for Android).

---

## 📸 Screenshots

<div align="center">
  <table>
    <tr>
      <td><img src="app screenshot/Screenshot_20260310_133824.jpg" width="180" /><br/><b>Dashboard</b></td>
      <td><img src="app screenshot/Screenshot_20260310_133839.jpg" width="180" /><br/><b>Map Engine</b></td>
      <td><img src="app screenshot/Screenshot_20260310_133851.jpg" width="180" /><br/><b>Fleet Orders</b></td>
      <td><img src="app screenshot/Screenshot_20260310_133906.jpg" width="180" /><br/><b>Profile</b></td>
    </tr>
  </table>
</div>

---

## 📈 Scalability & Future Improvements

- **TSP Algorithm Integration**: Moving from proximity sorting to a full Traveling Salesman Problem (TSP) solver for worker route batches.
- **Push Notification Service**: Implementation of FCM (Firebase Cloud Messaging) for instant dispatch alerts.
- **Analytics Engine**: Leveraging Supabase functions to generate weekly performance reports for fleet managers.

---

## 💡 Lessons Learned & Engineering Insights

- **State Management Resilience**: One of the critical engineering hurdles was managing the invalidation of multiple dependent providers (Auth, Map, Orders) during logout. Transitioning `late final` fields to `late` allowed the Riverpod `build()` method to refresh cleanly, preventing `LateInitializationError` during rapid state transitions.
- **Geo-Spatial Performance**: Rendering hundreds of map markers with real-time route updates required careful optimization of the Riverpod `listen` and `select` patterns to prevent UI jank.

---

## ✍️ Author

**Your Name**

- GitHub: [@yourusername](https://github.com/yourusername)
- LinkedIn: [Your Profile](https://linkedin.com/in/yourprofile)

---

## 📄 License

This project is proprietary property of **Scrapekia**.
