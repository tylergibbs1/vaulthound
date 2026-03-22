import Testing
import Foundation
@testable import VaulthoundCore
import VaulthoundModels

@Suite("RouteDiscovery")
struct RouteDiscoveryTests {
    let discovery = RouteDiscovery()

    // MARK: - Next.js App Router

    @Test("Discovers Next.js App Router routes")
    func nextjsAppRouter() throws {
        let tmp = try createTempProject {
            ("app/api/users/route.ts", """
            export async function GET(request: Request) {
              return Response.json({ users: [] })
            }

            export async function POST(request: Request) {
              return Response.json({ created: true })
            }
            """)
            ("app/api/users/[id]/route.ts", """
            export async function GET(request: Request, { params }: { params: { id: string } }) {
              return Response.json({ id: params.id })
            }

            export async function PUT(request: Request) {
              return Response.json({ updated: true })
            }

            export async function DELETE(request: Request) {
              return Response.json({ deleted: true })
            }
            """)
            ("app/api/auth/login/route.ts", """
            export async function POST(request: Request) {
              return Response.json({ token: "abc" })
            }
            """)
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)

        #expect(routes.count == 3)

        let usersRoute = routes.first { $0.path == "/api/users" }
        #expect(usersRoute != nil)
        #expect(usersRoute?.methods.contains(.GET) == true)
        #expect(usersRoute?.methods.contains(.POST) == true)
        #expect(usersRoute?.framework == .nextjsApp)

        let userByIdRoute = routes.first { $0.path == "/api/users/{{id}}" }
        #expect(userByIdRoute != nil)
        #expect(userByIdRoute?.methods.contains(.GET) == true)
        #expect(userByIdRoute?.methods.contains(.PUT) == true)
        #expect(userByIdRoute?.methods.contains(.DELETE) == true)

        let loginRoute = routes.first { $0.path == "/api/auth/login" }
        #expect(loginRoute != nil)
        #expect(loginRoute?.methods == [.POST])
    }

    @Test("Discovers Next.js App Router in src/app")
    func nextjsSrcApp() throws {
        let tmp = try createTempProject {
            ("src/app/api/health/route.ts", """
            export async function GET() {
              return Response.json({ status: "ok" })
            }
            """)
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.count == 1)
        #expect(routes[0].path == "/api/health")
        #expect(routes[0].methods == [.GET])
    }

    @Test("Handles catch-all and optional catch-all segments")
    func catchAllSegments() throws {
        let tmp = try createTempProject {
            ("app/api/[...slug]/route.ts", """
            export async function GET() { return new Response("ok") }
            """)
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.count == 1)
        #expect(routes[0].path == "/api/{{slug}}")
    }

    // MARK: - SvelteKit

    @Test("Discovers SvelteKit routes")
    func sveltekit() throws {
        let tmp = try createTempProject {
            ("src/routes/api/todos/+server.ts", """
            export async function GET({ url }) {
              return json([])
            }

            export async function POST({ request }) {
              return json({ created: true })
            }
            """)
            ("src/routes/api/todos/[id]/+server.ts", """
            export async function DELETE({ params }) {
              return json({ deleted: params.id })
            }
            """)
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.count == 2)

        let todosRoute = routes.first { $0.path == "/api/todos" }
        #expect(todosRoute?.framework == .sveltekit)
        #expect(todosRoute?.methods.contains(.GET) == true)
        #expect(todosRoute?.methods.contains(.POST) == true)

        let todoByIdRoute = routes.first { $0.path == "/api/todos/{{id}}" }
        #expect(todoByIdRoute?.methods == [.DELETE])
    }

    @Test("SvelteKit strips group directories")
    func sveltekitGroups() throws {
        let tmp = try createTempProject {
            ("src/routes/(app)/api/data/+server.ts", """
            export async function GET() { return json({}) }
            """)
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.count == 1)
        #expect(routes[0].path == "/api/data")
    }

    // MARK: - Nuxt

    @Test("Discovers Nuxt routes")
    func nuxt() throws {
        let tmp = try createTempProject {
            ("server/api/users.ts", """
            export default defineEventHandler((event) => {
              return { users: [] }
            })
            """)
            ("server/api/users/[id].get.ts", """
            export default defineEventHandler((event) => {
              return { user: getRouterParam(event, 'id') }
            })
            """)
            ("server/api/users/[id].delete.ts", """
            export default defineEventHandler((event) => {
              return { deleted: true }
            })
            """)
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.count == 3)

        let usersRoute = routes.first { $0.path == "/users" }
        #expect(usersRoute?.framework == .nuxt)

        let getUserRoute = routes.first { $0.path == "/users/{{id}}" && $0.methods == [.GET] }
        #expect(getUserRoute != nil)

        let deleteUserRoute = routes.first { $0.path == "/users/{{id}}" && $0.methods == [.DELETE] }
        #expect(deleteUserRoute != nil)
    }

    // MARK: - Edge Cases

    @Test("Returns empty for project with no API routes")
    func noRoutes() throws {
        let tmp = try createTempProject {
            ("src/index.ts", "console.log('hello')")
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.isEmpty)
    }

    @Test("Skips node_modules and build directories")
    func skipsNodeModules() throws {
        let tmp = try createTempProject {
            ("app/api/real/route.ts", "export async function GET() { return new Response('ok') }")
            ("node_modules/some-pkg/app/api/fake/route.ts", "export async function GET() { return new Response('fake') }")
            (".next/server/app/api/cached/route.js", "export async function GET() { return new Response('cached') }")
            ("package.json", "{}")
        }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let routes = discovery.discover(at: tmp)
        #expect(routes.count == 1)
        #expect(routes[0].path == "/api/real")
    }

    // MARK: - Helpers

    private func createTempProject(@TempFileBuilder _ files: () -> [(String, String)]) throws -> String {
        let tmp = NSTemporaryDirectory() + "vaulthound-test-\(UUID().uuidString)"
        let fm = FileManager.default

        for (path, content) in files() {
            let fullPath = URL(filePath: tmp).appending(path: path)
            try fm.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: fullPath, atomically: true, encoding: .utf8)
        }

        return tmp
    }
}

@resultBuilder
struct TempFileBuilder {
    static func buildBlock(_ components: (String, String)...) -> [(String, String)] {
        components
    }
}
