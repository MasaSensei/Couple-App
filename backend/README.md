# Couple App — Backend

Backend API untuk **Couple App**, sebuah platform private digital memory untuk pasangan.

Backend dibangun menggunakan Laravel dan digunakan oleh aplikasi Flutter sebagai REST API.

## Tech Stack

- PHP 8.5
- Laravel
- PostgreSQL 17
- Redis 7
- Laravel Sanctum
- Filament
- Docker & Docker Compose

## Architecture

Flutter
↓
Laravel REST API
↓
PostgreSQL

Filament
↓
Laravel
↓
PostgreSQL

## Project Structure

    backend/
    ├── app/
    │   ├── Filament/
    │   ├── Http/
    │   │   ├── Controllers/
    │   │   ├── Requests/
    │   │   ├── Resources/
    │   │   └── Responses/
    │   ├── Models/
    │   ├── Policies/
    │   └── Services/
    ├── bootstrap/
    ├── config/
    ├── database/
    │   ├── factories/
    │   ├── migrations/
    │   └── seeders/
    ├── docker/
    ├── public/
    ├── resources/
    ├── routes/
    ├── storage/
    ├── tests/
    │   ├── Feature/
    │   └── Unit/
    ├── .env.example
    ├── artisan
    ├── composer.json
    └── README.md

## Architecture Principles

Backend menggunakan struktur:

    Request
       ↓
    Controller
       ↓
    Service
       ↓
    Model
       ↓
    Database

Tanggung jawab setiap komponen:

- **Form Request** — validation
- **Controller** — HTTP orchestration
- **Service** — business logic
- **Model** — database & relationships
- **Policy** — authorization
- **API Resource** — response transformation
- **ApiResponse** — consistent API response structure

Pendekatan ini digunakan untuk menjaga codebase tetap sederhana, mudah dipahami, dan mudah dikembangkan tanpa overengineering.

## Current Features

### Authentication

- User registration
- User login
- User logout
- Get authenticated user
- Update user profile
- Laravel Sanctum authentication

### Couple

- Create couple
- Get current couple
- Join couple using invite code
- View couple by ID
- Couple membership
- Couple authorization
- Maximum two members per couple

### Admin Panel

Filament digunakan sebagai internal admin panel.

Admin dapat:

- View users
- View couples
- View couple members

Admin access dikontrol menggunakan `is_admin`.

Private user data dan future private photos tidak dirancang untuk dapat diakses sebagai plaintext oleh admin.

## API

Base path:

    /api/v1

### Authentication

    POST   /api/v1/auth/register
    POST   /api/v1/auth/login
    POST   /api/v1/auth/logout
    GET    /api/v1/me
    PATCH  /api/v1/me

### Couple

    POST   /api/v1/couple
    GET    /api/v1/couple
    POST   /api/v1/couple/join
    GET    /api/v1/couple/{coupleId}

## API Response Format

### Success

    {
        "success": true,
        "message": "Couple retrieved successfully.",
        "data": {
            "couple": {}
        }
    }

### Error

    {
        "success": false,
        "message": "Something went wrong.",
        "data": null
    }

### Validation Error

    {
        "success": false,
        "message": "The given data was invalid.",
        "data": {
            "errors": {
                "email": [
                    "The email has already been taken."
                ]
            }
        }
    }

## HTTP Status Codes

| Status | Usage                             |
| ------ | --------------------------------- |
| `200`  | Successful request                |
| `201`  | Resource created                  |
| `401`  | Unauthenticated                   |
| `403`  | Unauthorized                      |
| `404`  | Resource not found                |
| `422`  | Validation or business rule error |
| `500`  | Unexpected server error           |

## Development

The backend is designed to run inside Docker.

Run from the project root:

    docker compose up -d --build

Check running containers:

    docker compose ps

Run Laravel migrations:

    docker compose exec app php artisan migrate

Clear Laravel cache:

    docker compose exec app php artisan optimize:clear

Access Laravel application:

    http://localhost:8000

Filament admin panel:

    http://localhost:8000/admin

## Database

Development database:

    PostgreSQL 17
    Database: couples

Database configuration is stored in:

    backend/.env

The test environment uses a separate database configured through:

    backend/phpunit.xml

Tests must not use the development database.

## Testing

Automated tests cover:

- Authentication
- Registration
- Registration validation
- Login
- Logout
- User profile
- Couple creation
- Couple joining
- Couple business rules
- Couple authorization
- API validation
- API error handling
- Resource not found handling

Run all tests:

    docker compose exec app php artisan test

Run a specific test:

    docker compose exec app php artisan test --filter=TestName

## Docker Services

The development environment consists of:

    app
    ├── Laravel
    └── PHP 8.5

    postgres
    └── PostgreSQL 17

    redis
    └── Redis 7

Services are managed through:

    docker-compose.yml

## Security

Authentication uses Laravel Sanctum.

Authorization is enforced using Laravel Policies.

Sensitive operations should only be accessible to authorized users.

Future private photo storage will use client-side encryption so that private photo content is not designed to be readable as plaintext by the backend or admin panel.

## Project Status

### Phase 1 — Backend Foundation

Completed:

- Docker development environment
- Laravel backend
- PostgreSQL
- Redis
- Authentication
- User API
- Couple system
- Couple membership
- Authorization & Policies
- Filament admin panel
- API response contract
- Validation & error handling
- Automated testing

### Planned

Future development will include:

- Memory system
- Timeline
- Comments
- Photo management
- Client-side encrypted photos
- Secure object storage
- Backup and redundancy
- Integrity verification
- Recovery mechanisms
- Memory book
- Subscription system

## Monorepo

This backend is part of a larger monorepo.

    couple-app/
    ├── backend/          # Laravel API + Filament
    ├── frontend/         # Flutter application
    ├── docker-compose.yml
    └── README.md         # Main project documentation

For backend-specific documentation, see this file.

The root `README.md` contains documentation for the complete application.
