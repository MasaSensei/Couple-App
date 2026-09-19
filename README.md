# Couples App

A private digital space designed for couples to connect, organize, and preserve their shared memories.

> 🚧 This project is currently under active development.

---

## Tech Stack

### Frontend

- Flutter
- Dart
- Riverpod
- Dio
- GoRouter
- Flutter Secure Storage

### Backend

- Laravel
- PHP
- Laravel Sanctum
- FilamentPHP

### Database & Infrastructure

- PostgreSQL
- Redis
- Docker
- Docker Compose

---

# Project Architecture

```text
                    ┌─────────────────────┐
                    │    Flutter App      │
                    │                     │
                    │  Riverpod           │
                    │  Dio                │
                    │  GoRouter           │
                    └──────────┬──────────┘
                               │
                         REST API / JSON
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Laravel Backend   │
                    │                     │
                    │  Controllers        │
                    │  Services           │
                    │  Form Requests      │
                    │  Resources          │
                    │  Policies           │
                    └──────────┬──────────┘
                               │
                  ┌────────────┴────────────┐
                  │                         │
                  ▼                         ▼
          ┌───────────────┐         ┌───────────────┐
          │  PostgreSQL   │         │     Redis     │
          │               │         │               │
          │ Application   │         │ Cache / Queue │
          │ Data          │         │               │
          └───────────────┘         └───────────────┘
```

---

# Repository Structure

```text
couple-app/
│
├── backend/
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── docker/
│   ├── public/
│   ├── resources/
│   ├── routes/
│   ├── storage/
│   ├── tests/
│   ├── .env
│   ├── .env.example
│   ├── artisan
│   ├── composer.json
│   └── ...
│
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   ├── routing/
│   │   └── main.dart
│   ├── android/
│   ├── ios/
│   ├── pubspec.yaml
│   └── ...
│
├── docker-compose.yml
├── README.md
└── .gitignore
```

---

# Development Environment

The project uses Docker Compose for local backend development.

| Service    | Purpose             |   Port |
| ---------- | ------------------- | -----: |
| `app`      | Laravel API         | `8000` |
| `postgres` | PostgreSQL database | `5432` |
| `redis`    | Redis               | `6379` |

Start the backend environment:

```bash
docker compose up -d --build
```

Check containers:

```bash
docker compose ps
```

Stop containers:

```bash
docker compose down
```

---

# Backend Architecture

The Laravel backend follows a pragmatic Clean Code architecture.

```text
Request
   ↓
Controller
   ↓
Service
   ↓
Model
   ↓
Database
```

Supporting responsibilities:

- FormRequest → request validation
- Resource → API response transformation
- Policy → authorization
- Service → business logic
- Controller → HTTP orchestration

The project intentionally avoids unnecessary abstractions such as Repositories, Interfaces, DTOs, and Use Cases unless future complexity justifies them.

---

# API

Current API prefix:

```text
/api/v1
```

## Authentication

### Register

```http
POST /api/v1/auth/register
```

### Login

```http
POST /api/v1/auth/login
```

### Logout

```http
POST /api/v1/auth/logout
```

### Current User

```http
GET /api/v1/me
```

---

## Couple

### Create Couple

```http
POST /api/v1/couple
```

Creates a private couple space and generates an invite code.

### Get Current Couple

```http
GET /api/v1/couple
```

Returns the couple associated with the authenticated user.

### Join Couple

```http
POST /api/v1/couple/join
```

Example request:

```json
{
  "invite_code": "TBEWCRTQ"
}
```

### Get Couple by ID

```http
GET /api/v1/couple/{coupleId}
```

Access is restricted to couple members.

---

# Authentication Flow

Laravel Sanctum is used for API authentication.

Flutter stores the authentication token using:

```text
flutter_secure_storage
```

The token is automatically attached to authenticated API requests:

```http
Authorization: Bearer <token>
```

Application startup flow:

```text
App Start
   ↓
Splash
   ↓
Check Secure Storage
   ↓
Token exists?
   │
   ├── No ──→ Login
   │
   └── Yes
          ↓
        GET /me
          ↓
      Authenticated
          ↓
         Home
```

---

# Flutter Architecture

The Flutter application uses a feature-based architecture.

```text
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── error/
│   ├── network/
│   ├── storage/
│   ├── theme/
│   └── widgets/
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── presentation/
│   │   └── providers/
│   │
│   ├── home/
│   │   ├── data/
│   │   ├── presentation/
│   │   └── providers/
│   │
│   └── splash/
│       └── presentation/
│
├── routing/
│
└── main.dart
```

### State Management

Riverpod

### Networking

Dio

### Navigation

GoRouter

### Secure Storage

Flutter Secure Storage

---

# UI Direction

The application follows a:

**Soft Romantic × Cute × Premium**

visual direction.

Design principles:

- Warm off-white background
- Soft rose primary color
- Blush secondary accents
- Subtle lavender and peach accents
- White rounded cards
- Warm dark-gray typography
- Rounded buttons
- Minimal romantic illustrations
- Subtle animations
- Centralized design system

The visual style intentionally avoids an overly childish or heavily pink appearance.

---

# Phase 1 — Backend Foundation

**Status: COMPLETE**

Implemented:

- Laravel backend foundation
- Docker environment
- PostgreSQL
- Redis
- FilamentPHP
- Laravel Sanctum
- API versioning
- Authentication API
- User management
- Couple database structure
- Couple creation
- Couple joining
- Couple membership authorization
- API error handling
- Backend feature tests
- Separate testing database
- Centralized JSON API error responses

---

# Phase 2 — Flutter Foundation

**Status: COMPLETE**

Implemented:

- Flutter project
- Android development environment
- Feature-based project structure
- Riverpod
- Dio
- GoRouter
- Flutter Secure Storage
- Splash screen
- Register
- Login
- Logout
- Automatic authentication
- `GET /api/v1/me`
- Create Couple
- Get Couple
- Join Couple
- Couple state management
- Loading states
- Error states
- Basic navigation
- Flutter ↔ Laravel API integration

---

# Couple System

The current couple flow:

```text
User A
  │
  ├── Register
  │
  ├── Login
  │
  └── Create Couple
          │
          ▼
      Invite Code
          │
          │
          ▼
User B ──→ Join Couple
          │
          ▼
     Same Couple
          │
          ▼
       2 Members
```

A couple can contain a maximum of:

```text
2 users
```

The backend already supports returning the couple members through the API.

The Flutter application already has the couple data model and state management. Member presentation UI will be refined during the UI phase.

---

# Privacy Direction

Privacy is a core requirement of the project.

The application is designed around the concept of a private digital space for two users.

Future private media architecture is planned around:

```text
Flutter
   ↓
Client-side encryption
   ↓
Laravel API
   ↓
Encrypted Object Storage
```

The backend and admin system should not be designed around access to plaintext private photos.

Future storage and security requirements include:

- Client-side photo encryption
- Encrypted object storage
- Redundant storage
- Backup
- Integrity verification
- Automatic recovery
- Versioning
- Soft delete
- Recovery

These features are planned for future phases and are **not implemented yet**.

---

# Roadmap

## Phase 1 — Backend Foundation

```text
████████████████████ 100%
```

**Status: Complete**

---

## Phase 2 — Flutter Foundation

```text
████████████████████ 100%
```

**Status: Complete**

---

## Phase 3 — Core Couple Experience

Planned:

- Improved couple Home UI
- Couple member presentation
- Couple profile
- Better couple state handling
- Improved empty states
- Improved onboarding experience

---

## Future Features

Planned:

- Memories
- Date planning
- Timeline
- Photos
- Comments
- Photo booth
- Themes
- Memory book
- Subscription
- Client-side encrypted photos
- Redundant encrypted storage
- Backup and recovery
- Integrity verification
- Versioning
- Soft delete and recovery

---

# Development Principles

### 1. Build Incrementally

Features are implemented phase by phase instead of building the entire application at once.

### 2. Keep the Architecture Understandable

Prefer simple abstractions that solve real problems.

### 3. Security by Design

Private data should not be exposed unnecessarily.

### 4. API-First Communication

Flutter communicates with the backend through the Laravel REST API.

### 5. Separation of Responsibilities

Validation, business logic, authorization, API transformation, and UI state have separate responsibilities.

### 6. Stabilize Before Moving Forward

A development phase should be tested and stabilized before starting the next major feature.

---

# Local Development

## Start Backend

From the project root:

```bash
docker compose up -d --build
```

Laravel API:

```text
http://localhost:8000
```

---

## Start Flutter

From the frontend directory:

```bash
cd frontend
flutter pub get
flutter run
```

For Android Emulator, the Laravel API is accessed through:

```text
http://10.0.2.2:8000/api/v1
```

`10.0.2.2` allows the Android Emulator to access the host machine's `localhost`.

---

# Quality Checks

## Flutter

Run:

```bash
flutter analyze
```

Automated Flutter tests will be added as the project develops.

> Currently, the Flutter project does not contain a `test/` directory yet, so `flutter test` has not been introduced as part of the current validation workflow.

---

## Backend

Run the Laravel test suite:

```bash
docker compose exec app php artisan test
```

---

# Environment Variables

Local environment files containing secrets must not be committed.

Use:

```text
backend/.env
```

for local development.

The repository should contain:

```text
backend/.env.example
```

with safe example values.

Never commit:

```text
.env
```

or other files containing passwords, tokens, private keys, or production credentials.

---

# Current Status

```text
Backend Foundation       ████████████████████ 100%
Flutter Foundation       ████████████████████ 100%
Authentication            ████████████████████ 100%
Couple System             ████████████████████ 100%
Core Couple Experience    ░░░░░░░░░░░░░░░░░░░░   0%
Memories                  ░░░░░░░░░░░░░░░░░░░░   0%
Private Media             ░░░░░░░░░░░░░░░░░░░░   0%
```

> The percentages represent development phases and feature progress, not production readiness.

---

# Project Status

The project has completed its initial backend and Flutter foundations.

The next development phase will focus on improving the core couple experience and UI before introducing larger features.
