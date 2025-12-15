# 🚆 Travel Assist (User App) - Chennai Pilot 🇮🇳

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Status](https://img.shields.io/badge/Status-MVP%20Live-success?style=for-the-badge)

### *Last-Mile Luggage Assistance & Porter Service*
**Developer:** Paul Zion D | *DMI College of Engineering (2025 Batch)*

---

## 🧐 The Concept
Travel Assist connects travelers in Chennai with local partners (porters) who help carry luggage and guide them through stations. It bridges the gap between the taxi drop-off and the train coach.

## 🌟 Actual Features (MVP)

### 1. 🧳 Booking & Logistics
* **Service Types:** Users can book assistance for **Train** or **Bus** travel.
* **Location Picking:** Integrated **OpenStreetMap (OSM)** allows users to pin their exact Pickup and Drop locations (e.g., "Main Entrance" to "Platform 4").
* **Fare Estimation:** The app calculates a transparent price based on:
    * Number of Bags.
    * Base fare for the service type.

### 2. 🛒 Smart Pantry (Add-ons)
* Users can select items like **Water Bottles** or **Snacks** during the booking process.
* The Partner sees this request and purchases the items on their way to the location (reimbursed via the total fare).

### 3. 🛡️ Safety & Verification
* **SOS Button:** A dedicated emergency button on the tracking screen (simulates sending alerts).
* **Partner Verification:** Partners cannot accept jobs until they are manually approved by the Admin.
* **Admin Panel:** A separate dashboard where the Admin reviews Partner ID proofs before granting access.

### 4. 📍 Live Tracking
* Once a booking is accepted, the User can track the Partner's live location on the map.
* **Status Updates:** The app updates in real-time: *Partner Accepted* -> *Arrived* -> *In Progress* -> *Completed*.

---

## ⚙️ Tech Stack
* **Frontend:** Flutter (Mobile App).
* **Backend:** Firebase Authentication (Phone/Email) & Firestore Database.
* **Maps:** `flutter_map` (OpenStreetMap) with `latlong2`.
* **State Management:** Provider.

---

## 📲 How to Test (Android)
This is a student project pilot.

1.  Download **`User-App-v1.0.apk`** from the [**Releases**](https://github.com/paulzion/travel-assist-user-app/releases) section.
2.  Install on an Android device.
3.  *Note: To test the full flow, you need a second device running the 'Partner App' to accept the booking.*

---
### 👨‍💻 Developer
**Paul Zion D**
*Computer Science Engineering*
*DMI College of Engineering, Chennai (2025 Batch)*
linkedin.com/in/paulzion/
