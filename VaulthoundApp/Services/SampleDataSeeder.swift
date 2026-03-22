import Foundation
import SwiftData
import VaulthoundModels

/// Seeds realistic example data on first launch so users immediately
/// see what Vaulthound does without any setup.
@MainActor
struct SampleDataSeeder {

    static func seedIfNeeded(context: ModelContext) {
        // Only seed once — check for our marker project
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.name == "acme-web" })
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        // Also skip if user already has real projects
        let allProjects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        guard allProjects.isEmpty else { return }

        NSLog("Vaulthound: Seeding sample data for first launch")
        seedAcmeWeb(context: context)
        seedWeatherAPI(context: context)

        do {
            try context.save()
            NSLog("Vaulthound: Sample data seeded successfully")
        } catch {
            NSLog("Vaulthound: Failed to save sample data: \(error)")
        }
    }

    // MARK: - Acme Web (Full-stack SaaS example)

    private static func seedAcmeWeb(context: ModelContext) {
        let project = Project(name: "acme-web", path: "~/Developer/acme-web", detectedType: .node)
        project.isActive = true
        project.lastScannedAt = .now
        context.insert(project)

        // --- Local environment ---
        let local = ProjectEnvironment(name: "local", project: project)
        local.isActive = true
        context.insert(local)

        let localVars: [(String, String, Bool, SecretCategory?)] = [
            ("BASE_URL", "http://localhost:3000", false, nil),
            ("DATABASE_URL", "postgres://dev:dev@localhost:5432/acme_dev", false, nil),
            ("REDIS_URL", "redis://localhost:6379", false, nil),
            ("LOG_LEVEL", "debug", false, nil),
            ("OPENAI_API_KEY", "", true, .openAI),
            ("STRIPE_SECRET_KEY", "", true, .stripe),
            ("STRIPE_PUBLISHABLE_KEY", "pk_test_example123", false, .stripe),
            ("NEXT_PUBLIC_APP_URL", "http://localhost:3000", false, nil),
            ("JWT_SECRET", "", true, .generic),
            ("RESEND_API_KEY", "", true, .generic),
        ]

        for (i, (key, value, isSecret, category)) in localVars.enumerated() {
            let v = Variable(key: key, value: value, isSecret: isSecret, sortOrder: i)
            v.detectedCategory = category
            v.projectEnvironment = local
            if isSecret { v.isMissing = true }
            context.insert(v)
        }

        // --- Staging environment ---
        let staging = ProjectEnvironment(name: "staging", project: project)
        context.insert(staging)

        let stagingVars: [(String, String, Bool, SecretCategory?)] = [
            ("BASE_URL", "https://staging.acme.dev", false, nil),
            ("DATABASE_URL", "", true, .generic),
            ("REDIS_URL", "redis://staging-cache.acme.dev:6379", false, nil),
            ("LOG_LEVEL", "info", false, nil),
            ("OPENAI_API_KEY", "", true, .openAI),
            ("STRIPE_SECRET_KEY", "", true, .stripe),
            ("STRIPE_PUBLISHABLE_KEY", "pk_test_staging456", false, .stripe),
            ("NEXT_PUBLIC_APP_URL", "https://staging.acme.dev", false, nil),
            ("JWT_SECRET", "", true, .generic),
            ("RESEND_API_KEY", "", true, .generic),
        ]

        for (i, (key, value, isSecret, category)) in stagingVars.enumerated() {
            let v = Variable(key: key, value: value, isSecret: isSecret, sortOrder: i)
            v.detectedCategory = category
            v.projectEnvironment = staging
            if isSecret { v.isMissing = true }
            context.insert(v)
        }

        // --- Production environment ---
        let prod = ProjectEnvironment(name: "production", project: project)
        context.insert(prod)

        let prodVars: [(String, String, Bool, SecretCategory?)] = [
            ("BASE_URL", "https://acme.dev", false, nil),
            ("DATABASE_URL", "", true, .generic),
            ("REDIS_URL", "", true, .generic),
            ("LOG_LEVEL", "warn", false, nil),
            ("OPENAI_API_KEY", "", true, .openAI),
            ("STRIPE_SECRET_KEY", "", true, .stripe),
            ("STRIPE_PUBLISHABLE_KEY", "pk_live_prod789", false, .stripe),
            ("NEXT_PUBLIC_APP_URL", "https://acme.dev", false, nil),
            ("JWT_SECRET", "", true, .generic),
            ("RESEND_API_KEY", "", true, .generic),
            ("SENTRY_DSN", "https://abc123@o456.ingest.sentry.io/789", false, nil),
            ("CDN_URL", "https://cdn.acme.dev", false, nil),
        ]

        for (i, (key, value, isSecret, category)) in prodVars.enumerated() {
            let v = Variable(key: key, value: value, isSecret: isSecret, sortOrder: i)
            v.detectedCategory = category
            v.projectEnvironment = prod
            if isSecret { v.isMissing = true }
            context.insert(v)
        }

        // --- API Collections ---
        let authCollection = RequestCollection(name: "Auth", project: project, sortOrder: 0)
        context.insert(authCollection)

        let loginRequest = APIRequest(
            name: "Login",
            method: .POST,
            urlTemplate: "{{BASE_URL}}/api/auth/login",
            headers: [
                RequestHeader(key: "Content-Type", value: "application/json"),
            ],
            bodyType: .json,
            sortOrder: 0
        )
        loginRequest.bodyContent = """
        {
          "email": "user@example.com",
          "password": "password123"
        }
        """
        loginRequest.collection = authCollection
        context.insert(loginRequest)

        let signupRequest = APIRequest(
            name: "Sign Up",
            method: .POST,
            urlTemplate: "{{BASE_URL}}/api/auth/signup",
            headers: [
                RequestHeader(key: "Content-Type", value: "application/json"),
            ],
            bodyType: .json,
            sortOrder: 1
        )
        signupRequest.bodyContent = """
        {
          "name": "Jane Doe",
          "email": "jane@example.com",
          "password": "securepass456"
        }
        """
        signupRequest.collection = authCollection
        context.insert(signupRequest)

        let refreshRequest = APIRequest(
            name: "Refresh Token",
            method: .POST,
            urlTemplate: "{{BASE_URL}}/api/auth/refresh",
            headers: [
                RequestHeader(key: "Content-Type", value: "application/json"),
                RequestHeader(key: "Authorization", value: "Bearer {{JWT_TOKEN}}"),
            ],
            bodyType: .none,
            sortOrder: 2
        )
        refreshRequest.collection = authCollection
        context.insert(refreshRequest)

        let usersCollection = RequestCollection(name: "Users", project: project, sortOrder: 1)
        context.insert(usersCollection)

        let listUsersRequest = APIRequest(
            name: "List Users",
            method: .GET,
            urlTemplate: "{{BASE_URL}}/api/users?page=1&limit=20",
            headers: [
                RequestHeader(key: "Authorization", value: "Bearer {{JWT_TOKEN}}"),
                RequestHeader(key: "Accept", value: "application/json"),
            ],
            sortOrder: 0
        )
        listUsersRequest.collection = usersCollection
        context.insert(listUsersRequest)

        let getUserRequest = APIRequest(
            name: "Get User",
            method: .GET,
            urlTemplate: "{{BASE_URL}}/api/users/{{USER_ID}}",
            headers: [
                RequestHeader(key: "Authorization", value: "Bearer {{JWT_TOKEN}}"),
            ],
            sortOrder: 1
        )
        getUserRequest.collection = usersCollection
        context.insert(getUserRequest)

        let updateUserRequest = APIRequest(
            name: "Update User",
            method: .PATCH,
            urlTemplate: "{{BASE_URL}}/api/users/{{USER_ID}}",
            headers: [
                RequestHeader(key: "Content-Type", value: "application/json"),
                RequestHeader(key: "Authorization", value: "Bearer {{JWT_TOKEN}}"),
            ],
            bodyType: .json,
            sortOrder: 2
        )
        updateUserRequest.bodyContent = """
        {
          "name": "Jane Smith",
          "role": "admin"
        }
        """
        updateUserRequest.collection = usersCollection
        context.insert(updateUserRequest)

        let aiCollection = RequestCollection(name: "AI", project: project, sortOrder: 2)
        context.insert(aiCollection)

        let chatRequest = APIRequest(
            name: "Chat Completion",
            method: .POST,
            urlTemplate: "https://api.openai.com/v1/chat/completions",
            headers: [
                RequestHeader(key: "Content-Type", value: "application/json"),
                RequestHeader(key: "Authorization", value: "Bearer {{OPENAI_API_KEY}}"),
            ],
            bodyType: .json,
            sortOrder: 0
        )
        chatRequest.bodyContent = """
        {
          "model": "gpt-4o",
          "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Explain environment variables in one sentence."}
          ],
          "max_tokens": 150
        }
        """
        chatRequest.collection = aiCollection
        context.insert(chatRequest)

        let anthropicRequest = APIRequest(
            name: "Claude Message",
            method: .POST,
            urlTemplate: "https://api.anthropic.com/v1/messages",
            headers: [
                RequestHeader(key: "Content-Type", value: "application/json"),
                RequestHeader(key: "x-api-key", value: "{{ANTHROPIC_API_KEY}}"),
                RequestHeader(key: "anthropic-version", value: "2023-06-01"),
            ],
            bodyType: .json,
            sortOrder: 1
        )
        anthropicRequest.bodyContent = """
        {
          "model": "claude-sonnet-4-20250514",
          "max_tokens": 256,
          "messages": [
            {"role": "user", "content": "What is the best way to manage .env files?"}
          ]
        }
        """
        anthropicRequest.collection = aiCollection
        context.insert(anthropicRequest)
    }

    // MARK: - Weather API (Simple public API example)

    private static func seedWeatherAPI(context: ModelContext) {
        let project = Project(name: "weather-app", path: "~/Developer/weather-app", detectedType: .swift)
        project.lastScannedAt = .now
        context.insert(project)

        let local = ProjectEnvironment(name: "local", project: project)
        local.isActive = true
        context.insert(local)

        let vars: [(String, String, Bool, SecretCategory?)] = [
            ("WEATHER_API_KEY", "", true, .generic),
            ("WEATHER_BASE_URL", "https://api.openweathermap.org/data/2.5", false, nil),
            ("DEFAULT_CITY", "San Francisco", false, nil),
            ("UNITS", "imperial", false, nil),
            ("CACHE_TTL_SECONDS", "300", false, nil),
        ]

        for (i, (key, value, isSecret, category)) in vars.enumerated() {
            let v = Variable(key: key, value: value, isSecret: isSecret, sortOrder: i)
            v.detectedCategory = category
            v.projectEnvironment = local
            if isSecret { v.isMissing = true }
            context.insert(v)
        }

        let collection = RequestCollection(name: "Weather", project: project, sortOrder: 0)
        context.insert(collection)

        let currentWeather = APIRequest(
            name: "Current Weather",
            method: .GET,
            urlTemplate: "{{WEATHER_BASE_URL}}/weather?q={{DEFAULT_CITY}}&units={{UNITS}}&appid={{WEATHER_API_KEY}}",
            headers: [
                RequestHeader(key: "Accept", value: "application/json"),
            ],
            sortOrder: 0
        )
        currentWeather.collection = collection
        context.insert(currentWeather)

        let forecast = APIRequest(
            name: "5-Day Forecast",
            method: .GET,
            urlTemplate: "{{WEATHER_BASE_URL}}/forecast?q={{DEFAULT_CITY}}&units={{UNITS}}&appid={{WEATHER_API_KEY}}",
            headers: [
                RequestHeader(key: "Accept", value: "application/json"),
            ],
            sortOrder: 1
        )
        forecast.collection = collection
        context.insert(forecast)
    }
}
