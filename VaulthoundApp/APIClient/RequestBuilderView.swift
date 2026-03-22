import SwiftUI
import SwiftData
import VaulthoundModels
import VaulthoundCore

struct RequestBuilderView: View {
    let project: Project

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var isLoading = false
    @State private var lastResponse: APIResponse?
    @State private var errorMessage: String?

    private var selectedRequest: APIRequest? {
        guard let id = appState.selectedRequestID else { return nil }
        return project.collections
            .flatMap { $0.requests }
            .first { $0.persistentModelID == id }
    }

    var body: some View {
        if let request = selectedRequest {
            VSplitView {
                requestEditor(for: request)
                    .frame(minHeight: 200)

                responseViewer
                    .frame(minHeight: 200)
            }
        } else {
            ContentUnavailableView(
                "No Request Selected",
                systemImage: "globe",
                description: Text("Select a request from the sidebar or create a new one.")
            )
        }
    }

    @ViewBuilder
    private func requestEditor(for request: APIRequest) -> some View {
        VStack(spacing: 0) {
            // Method + URL bar
            HStack(spacing: 8) {
                Picker("", selection: Binding(
                    get: { request.method },
                    set: { request.method = $0 }
                )) {
                    ForEach(HTTPMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .frame(width: 100)

                TextField("URL (supports {{variables}})", text: Binding(
                    get: { request.urlTemplate },
                    set: { request.urlTemplate = $0 }
                ))
                .font(.body.monospaced())
                .textFieldStyle(.roundedBorder)

                Button {
                    Task { await sendRequest(request) }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isLoading || request.urlTemplate.isEmpty)
            }
            .padding()

            Divider()

            // Tabs: Params, Headers, Body, Auth
            TabView {
                RequestHeaderEditor(request: request)
                    .tabItem { Text("Headers") }

                RequestBodyEditor(request: request)
                    .tabItem { Text("Body") }
            }
        }
    }

    @ViewBuilder
    private var responseViewer: some View {
        if let response = lastResponse {
            ResponseView(response: response)
        } else if let error = errorMessage {
            ContentUnavailableView(
                "Request Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else {
            ContentUnavailableView(
                "No Response",
                systemImage: "arrow.up.circle",
                description: Text("Send a request to see the response.")
            )
        }
    }

    private func sendRequest(_ request: APIRequest) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Build variables dictionary from active environment
        let variables = buildVariablesDictionary()

        do {
            let result = try await HTTPClientService.shared.execute(
                request: request,
                variables: variables
            )

            let snapshot = RequestSnapshot(
                method: request.method.rawValue,
                url: VariableInterpolator().resolve(request.urlTemplate, using: variables),
                headers: Dictionary(uniqueKeysWithValues: request.headers.filter(\.isEnabled).map { ($0.key, $0.value) }),
                body: request.bodyContent
            )

            let response = APIResponse(
                statusCode: result.statusCode,
                responseHeaders: result.headers,
                body: result.body,
                bodyContentType: result.contentType,
                timing: result.timing,
                requestSnapshot: snapshot
            )
            response.request = request
            modelContext.insert(response)

            // Enforce 50-item history limit
            let history = request.responseHistory.sorted { $0.receivedAt > $1.receivedAt }
            if history.count > 50 {
                for old in history.dropFirst(50) {
                    modelContext.delete(old)
                }
            }

            lastResponse = response
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildVariablesDictionary() -> [String: String] {
        guard let env = project.environments.first(where: { $0.isActive }) ?? project.environments.first else {
            return [:]
        }

        var dict: [String: String] = [:]
        for variable in env.variables {
            if variable.isSecret, let ref = variable.keychainRef {
                dict[variable.key] = (try? KeychainService.shared.read(account: ref)) ?? ""
            } else {
                dict[variable.key] = variable.value
            }
        }
        return dict
    }
}

// MARK: - Request List (middle column in API mode)

struct RequestListView: View {
    let project: Project

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedRequestID) {
            ForEach(sortedCollections) { collection in
                Section(collection.name) {
                    ForEach(collection.requests.sorted { $0.sortOrder < $1.sortOrder }) { request in
                        HStack(spacing: 6) {
                            Text(request.method.rawValue)
                                .font(.caption.monospaced().bold())
                                .foregroundStyle(methodColor(request.method))
                                .frame(width: 50, alignment: .leading)

                            Text(request.name)
                                .lineLimit(1)
                        }
                        .tag(request.persistentModelID)
                        .contextMenu {
                            Button("Duplicate") {
                                duplicateRequest(request, in: collection)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                modelContext.delete(request)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    addRequest()
                } label: {
                    Label("New Request", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Spacer()
            }
            .background(.bar)
        }
    }

    private var sortedCollections: [RequestCollection] {
        project.collections.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: return .blue
        case .POST: return .green
        case .PUT: return .orange
        case .PATCH: return .yellow
        case .DELETE: return .red
        case .HEAD: return .purple
        case .OPTIONS: return .gray
        }
    }

    private func addRequest() {
        let collection: RequestCollection
        if let existing = project.collections.first {
            collection = existing
        } else {
            collection = RequestCollection(name: "Default", project: project)
            modelContext.insert(collection)
        }

        let request = APIRequest(
            name: "New Request",
            sortOrder: collection.requests.count
        )
        request.collection = collection
        modelContext.insert(request)
        appState.selectedRequestID = request.persistentModelID
    }

    private func duplicateRequest(_ request: APIRequest, in collection: RequestCollection) {
        let dupe = APIRequest(
            name: "\(request.name) (copy)",
            method: request.method,
            urlTemplate: request.urlTemplate,
            headers: request.headers,
            bodyType: request.bodyType,
            sortOrder: collection.requests.count
        )
        dupe.bodyContent = request.bodyContent
        dupe.collection = collection
        modelContext.insert(dupe)
    }
}
