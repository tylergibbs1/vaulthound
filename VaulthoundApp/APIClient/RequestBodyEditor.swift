import SwiftUI
import VaulthoundModels

struct RequestBodyEditor: View {
    let request: APIRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("Body Type", selection: Binding(
                    get: { request.bodyType },
                    set: { request.bodyType = $0 }
                )) {
                    Text("None").tag(BodyType.none)
                    Text("JSON").tag(BodyType.json)
                    Text("Form").tag(BodyType.formData)
                    Text("XML").tag(BodyType.xml)
                    Text("Raw").tag(BodyType.raw)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 350)

                Spacer()

                if request.bodyType == .json {
                    Button("Format") {
                        formatJSON()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)

            Divider()

            if request.bodyType == .none {
                ContentUnavailableView(
                    "No Body",
                    systemImage: "doc.text",
                    description: Text("Select a body type above.")
                )
            } else {
                TextEditor(text: Binding(
                    get: { request.bodyContent ?? "" },
                    set: { request.bodyContent = $0 }
                ))
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func formatJSON() {
        guard let content = request.bodyContent,
              let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8)
        else { return }

        request.bodyContent = str
    }
}
