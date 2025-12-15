# 🚆 Travel Assist (User App) - The Chennai Pilot 🇮🇳

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Status](https://img.shields.io/badge/Status-MVP%20Live-success?style=for-the-badge)

### *Redefining "Last-Mile" Travel Logistics in India*
**Developer:** Paul Zion D | *DMI College of Engineering (2025 Batch)*

---

## 🧐 The Problem
Traveling in India—especially in bustling hubs like **Chennai Central** or **Tambaram**—is physically exhausting.
* **The Struggle:** Moving heavy luggage from a taxi to the train coach (or vice versa) is chaos.
* **The Gap:** Uber/Ola gets you *to* the station, but nobody helps you *inside* the station.
* **The Safety Issue:** Finding trustworthy help is risky, especially for solo female travelers or the elderly.

## 💡 The Solution: Travel Assist
**Travel Assist** is a hyper-local logistics platform that connects travelers with verified **Personal Travel Assistants (Porters)**. It’s not just about luggage; it’s about **dignity, safety, and convenience**.

---

## 🌟 Comprehensive Feature Breakdown

### 1. 🧳 Multi-Modal Porter Booking (Chennai Specific)
We understand Chennai's complex transport network. The app is engineered to handle the unique logistics of every major transit mode in the city:

* **🚆 Indian Railways (Long Distance):**
    * Optimized for major terminals like **Puratchi Thalaivar Dr. M.G.R. Central (MAS)** and **Chennai Egmore (MS)**.
    * Partners assist with navigating long platforms and coach finding.
* **🚋 Suburban & MRTS (Local Trains):**
    * Dedicated support for the "Lifeline of Chennai" commuters at **Tambaram**, **Guindy**, and **St. Thomas Mount**.
    * Includes the **Velachery MRTS** line, helping professionals carry loads during peak hours.
* **🚇 Metro (CMRL):**
    * Fast assistance for the modern **Chennai Metro (Blue & Green Lines)**.
    * Partners help navigate multi-level underground stations (e.g., Central Metro, Anna Nagar East).
* **🚌 Bus (MTC & SETC):**
    * **Intercity (SETC):** Handling heavy luggage at the massive **CMBT (Koyambedu)** and the new **KCBT (Kilambakkam)** terminus.
    * **Local (MTC):** Helping passengers board crowded town buses at hubs like **Broadway** or **T. Nagar**.

**The "Fair Price" Engine:**
Unlike random bargaining at stations, the app calculates a fixed, fair price based on:
* *Transit Complexity* (e.g., KCBT requires longer walks than a Metro station).
* *Luggage Count* (Heavy vs. Medium).
* *Wait Time* (Dynamic adjustment if trains are delayed).

### 2. 🛒 The "Smart Pantry" (Innovative Feature)
Why stop at luggage? Users can "order" essentials while booking the porter.
* **How it works:** A user selects "Add-ons" like *Water Bottles (1L)*, *Chips/Snacks*, or *Sanitary Pads*.
* **The Logic:** The Partner accepts the job, sees the shopping list, buys the items on their way to the pickup point, and hands them over upon meeting.
* **Value:** Saves the traveler from running around shops with heavy bags.

### 3. 🛡️ Safety Architecture (The "Guardian" System)
Safety is the core pillar of this project.
* **♀️ Female Priority Algorithm:** If the user is female, the app's matching logic prioritizes finding a **Female Partner**. This encourages safety and comfort.
* **🆘 SOS Emergency Button:** One-tap alert system that broadcasts location to emergency contacts (simulated in MVP).
* **🆔 100% Verified Workforce:** Every Partner is verified via Aadhar/Voter ID in our separate **Admin Panel** before they can accept jobs.

### 4. ♿ Accessibility & Special Assistance
We built this for everyone, including those who need more than just muscle.
* **Elderly Assist:** Partners are trained to offer physical support (walking assistance) to senior citizens.
* **Wheelchair Handling:** Specific option to request partners capable of maneuvering wheelchairs across ramps and elevators.

### 5. 📍 Precision Navigation (Zero-Cost Tech)
* **The Tech:** We bypassed expensive Google Maps APIs by integrating **OpenStreetMap (OSM)** via `flutter_map`.
* **The Feature:** Users can drag a pin to their *exact* standing spot (e.g., "Main Entrance, Pillar 4").
* **Live Tracking:** Once the partner accepts, the user sees the partner's movement in real-time on the map.

---

## ⚙️ Technical Deep Dive

### Architecture
The app follows a strict **MVVM (Model-View-ViewModel)** architecture to ensure scalable and clean code.
* **Provider:** Used for State Management (managing cart state, user session, and live booking status).
* **Services:** Separated logic for `AuthService`, `LocationService`, and `BookingService`.

### Backend: Firebase Ecosystem
* **Authentication:** Phone Number (OTP) & Email login.
* **Cloud Firestore:** NoSQL database handling complex relationships:
    * `users`: Profiles and saved addresses.
    * `bookings`: The core transaction document containing status stages (`pending` -> `accepted` -> `arrived` -> `started` -> `completed`).
* **Geo-Queries:** Filtering partners based on proximity (radius search).

---

## 📲 User Journey (How it Works)
1.  **Onboarding:** User signs up & grants Location Permission.
2.  **Selection:** Chooses Service (Train/Bus/Metro) and inputs luggage count.
3.  **Add-ons:** (Optional) Adds Water/Snacks from the Smart Pantry.
4.  **Location:** Picks "Pickup" and "Drop" points on the OSM Map.
5.  **Matching:** The request is broadcast to nearby Partners.
6.  **Live Service:**
    * *Partner Accepts* -> User sees profile & OTP.
    * *Partner Arrives* -> User verifies via OTP.
    * *Journey Starts* -> Real-time tracking.
7.  **Payment:** Cash/UPI (Simulated) payment upon completion.

---

## 📸 Installation & Testing
This project is currently live as a **Pilot in Chennai**. You can test the app on any Android device.

1.  Navigate to the [**Releases**](https://github.com/paulzion/travel-assist-user-app/releases) section.
2.  Download **`User-App-v1.0.apk`**.
3.  Install and Run.
4.  *Note: To simulate a full cycle, you will need the 'Partner App' running on a second device to accept the request.*

---

## 🔮 Roadmap
* **Phase 2:** Integration with **IRCTC API** to auto-fetch train PNR and schedule porters automatically.
* **Phase 3:** Expansion to Bangalore (SBC) and Hyderabad (Nampally).
* **Phase 4:** AI-driven demand prediction for Partners (Heatmaps).

---
### 👨‍💻 Connect
**Paul Zion D**
*Computer Science Engineering*
*DMI College of Engineering, Chennai (2025 Batch)*
https://www.linkedin.com/in/paulzion/
