# Couple App

A private digital memory platform designed for couples.

Couple App is designed to provide a private space for couples to store, organize, and revisit their shared memories, with privacy and data security as core considerations.

## Project Overview

Couple App is developed as a monorepo consisting of:

- **Backend** — Laravel REST API and Filament admin panel
- **Frontend** — Flutter mobile application
- **Infrastructure** — Docker and Docker Compose

## Architecture

    Flutter Mobile App
            │
            │ REST API
            ▼
    Laravel Backend
            │
       ┌────┴────┐
       ▼         ▼
    PostgreSQL  Redis

    Filament Admin
            │
            ▼
    Laravel Backend
            │
            ▼
       PostgreSQL

## Tech Stack

### Backend

- PHP 8.5
- Laravel
- PostgreSQL 17
- Redis 7
- Laravel Sanctum
- Filament

### Frontend

- Flutter
- Dart

### Infrastructure

- Docker
- Docker Compose

## Repository Structure

    couple-app/
    ├── backend/              # Laravel REST API + Filament
    ├── frontend/             # Flutter mobile application
    ├── docker-compose.yml    # Development infrastructure
    ├── .gitignore
    └── README.md             # Main project documentation

## Backend

The backend provides the REST API used by the Flutter application.

Current backend features include:

- Authentication
- User registration and login
- User profile management
- Couple creation
- Couple membership
- Invite code system
- Couple authorization
- Laravel Sanctum authentication
- Filament admin panel
- API validation and error handling
- Automated tests

Backend documentation:

    backend/README.md

## Frontend

The Flutter application will consume the Laravel REST API and provide the mobile user interface.

Planned responsibilities include:

- Authentication
- Couple management
- Memory management
- Timeline
- Photo management
- Comments
- Memory book
- Subscription-related features

Frontend documentation will be added as development progresses.

## Privacy & Security

Privacy is one of the main design considerations of Couple App.

The system is designed with the following principles:

- Authentication and authorization are enforced at the API level.
- Couple data is only accessible to authorized members.
- Administrative access is separated from normal user access.
- Private photos are planned to use client-side encryption.
- The backend should not be designed around unrestricted plaintext access to private photos.
- Backup and redundancy will be considered for long-term data preservation.

Security mechanisms may evolve as the application develops.

## Development Environment

The development environment uses Docker.

From the project root:

    docker compose up -d --build

Check running services:

    docker compose ps

The main development services are:

    app
    └── Laravel / PHP 8.5

    postgres
    └── PostgreSQL 17

    redis
    └── Redis 7

The Laravel backend is available at:

    http://localhost:8000

The Filament admin panel is available at:

    http://localhost:8000/admin

## Testing

Backend automated tests can be executed with:

    docker compose exec app php artisan test

The backend uses a separate test database to prevent automated tests from modifying the development database.

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
- Authorization and Policies
- Filament admin panel
- API response contract
- Validation and error handling
- Automated testing

### Next Development Phase

The next development phase will focus on the application's core memory functionality.

Planned features include:

- Memory system
- Timeline
- Comments
- Photo management
- Private encrypted photos
- Secure object storage
- Backup and redundancy
- Integrity verification
- Recovery mechanisms
- Memory book
- Subscription system

## Development Principles

The project follows a pragmatic Clean Code approach.

The backend generally follows:

    Request
       ↓
    Controller
       ↓
    Service
       ↓
    Model
       ↓
    Database

The architecture aims to keep responsibilities clear without introducing unnecessary abstractions or overengineering.

## Monorepo

This repository contains the complete Couple App project.

    couple-app/
    ├── backend/
    ├── frontend/
    ├── docker-compose.yml
    └── README.md

Each major component may contain its own documentation.

## License

This project is currently private and is not licensed for redistribution.
