import SwiftUI
import VaulthoundModels

struct RequestHeaderEditor: View {
    let request: APIRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(Array(request.headers.enumerated()), id: \.offset) { index, header in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { header.isEnabled },
                            set: { newValue in
                                var updated = request.headers
                                updated[index].isEnabled = newValue
                                request.headers = updated
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        TextField("Key", text: Binding(
                            get: { header.key },
                            set: { newValue in
                                var updated = request.headers
                                updated[index].key = newValue
                                request.headers = updated
                            }
                        ))
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)

                        TextField("Value", text: Binding(
                            get: { header.value },
                            set: { newValue in
                                var updated = request.headers
                                updated[index].value = newValue
                                request.headers = updated
                            }
                        ))
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)

                        Button {
                            var updated = request.headers
                            updated.remove(at: index)
                            request.headers = updated
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .listStyle(.plain)

            Divider()

            Button {
                request.headers.append(RequestHeader(key: "", value: ""))
            } label: {
                Label("Add Header", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
    }
}
