# Project Overview

This is a Flutter project named "prostock," designed as a comprehensive point-of-sale (POS) and inventory management system. It adopts an offline-first approach, ensuring full functionality even without internet connectivity. The application leverages Firebase for backend services (Authentication, Firestore, Storage) and `sqflite` for local data persistence. State management is handled using the `provider` package.

**Key Features:**
*   **User Authentication & Authorization:** Supports different user roles (admin, regular user) with Firebase Authentication.
*   **Product Management:** CRUD operations for products, including barcode support, stock management, and price history.
*   **Customer Management:** CRUD operations for customers, including credit management.
*   **Sales Management:** Handles sales transactions, including offline sales and synchronization.
*   **Inventory Management:** Track stock movements, receive stock, and manage inventory levels.
*   **Offline-First Capabilities:** Utilizes a robust offline manager to queue and sync operations when connectivity is restored.
*   **Reporting and Analytics:** Generate sales, inventory, and financial reports with charts (`fl_chart`).
*   **Barcode Scanning:** Scan product barcodes using the device's camera (`mobile_scanner`).
*   **Image Uploads:** Capture and upload product images to Cloudinary (`image_picker`, `cloudinary_public`).
*   **Bluetooth Printing:** Print receipts using a Bluetooth thermal printer (`bluetooth_thermal_printer_plus`).
*   **Background Sync:** Automatically synchronize data in the background (`background_fetch`).
*   **Activity Logging:** Tracks user activities for auditing.
*   **Error Handling:** Comprehensive error logging and custom exceptions.

# Building and Running

This is a standard Flutter project.

*   **Dependencies:** Managed by `pubspec.yaml`.
*   **Firebase Configuration:** `firebase_options.dart` is used for Firebase initialization.
*   **Local Database:** `sqflite` is used for local data storage.

To set up and run the project:

1.  **Install Flutter:** If you haven't already, follow the official Flutter installation guide: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
2.  **Get Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the Application:**
    ```bash
    flutter run
    ```
    Or, to run on a specific device:
    ```bash
    flutter run -d <device_id>
    ```
    (You can get device IDs by running `flutter devices`)

# Development Conventions

*   **Architecture:** The project follows a layered architecture with clear separation of concerns (models, providers, screens, services, utils, widgets).
*   **State Management:** `provider` package is used for managing application state.
*   **Data Persistence:**
    *   **Online:** Firebase Firestore for cloud data storage.
    *   **Offline:** `sqflite` for local database storage, managed by `LocalDatabaseService`.
*   **Offline Synchronization:** `OfflineManager` handles queuing and syncing of operations between local database and Firestore.
*   **Code Style:** Adheres to Dart's recommended coding practices and lint rules (configured in `analysis_options.yaml`).
*   **Error Handling:** Custom `FirestoreException` and `ErrorLogger` for consistent error reporting.
*   **Security:** Input validation and sanitization are implemented in `FirestoreService` to prevent common vulnerabilities.
*   **Testing:** The `test` directory contains unit and integration tests.
    *   `flutter test` to run all tests.
    *   `flutter test test/<file_name>.dart` to run specific tests.
    *   Mocking is done using `mockito` and `fake_cloud_firestore`.

# Key Dependencies

*   **`flutter`:** The core framework for building the application.
*   **`firebase_core`**, **`firebase_auth`**, **`cloud_firestore`**, **`firebase_storage`:** For backend services like authentication, database, and file storage.
*   **`sqflite`:** For local database storage.
*   **`provider`:** For state management.
*   **`mobile_scanner`:** For barcode scanning.
*   **`fl_chart`:** For creating charts and reports.
*   **`image_picker`** and **`cloudinary_public`:** For picking images and uploading them to Cloudinary.
*   **`bluetooth_thermal_printer_plus`** and **`esc_pos_utils_plus`:** For printing receipts.
*   **`background_fetch`:** For background data synchronization.
*   **`shared_preferences`:** For simple key-value storage.
*   **`connectivity_plus`:** To check network connectivity status.
*   **`permission_handler`:** To handle device permissions.