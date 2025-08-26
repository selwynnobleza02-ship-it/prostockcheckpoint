# Project Overview

This is a Flutter project named "prostock," designed as a point-of-sale (POS) and inventory management system. It adopts an offline-first approach, ensuring full functionality even without internet connectivity. The application leverages Firebase for backend services (Authentication, Firestore, Storage) and `sqflite` for local data persistence. State management is handled using the `provider` package.

**Key Features:**
*   **User Authentication & Authorization:** Supports different user roles (admin, regular user).
*   **Product Management:** CRUD operations for products, including barcode support, stock management, and price history.
*   **Customer Management:** CRUD operations for customers, including credit management.
*   **Sales Management:** Handles sales transactions, including offline sales and synchronization.
*   **Offline-First Capabilities:** Utilizes a robust offline manager to queue and sync operations when connectivity is restored.
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
