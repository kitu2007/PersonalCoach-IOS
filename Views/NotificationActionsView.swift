import SwiftUI
import SwiftData
import UserNotifications

struct NotificationActionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingAddAction = false
    @State private var selectedAction: NotificationManager.NotificationAction?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Default Actions")) {
                    ForEach(notificationManager.defaultActions) { action in
                        HStack {
                            Text(action.title)
                            Spacer()
                            Text(action.identifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Custom Actions")) {
                    ForEach(notificationManager.customActions) { action in
                        HStack {
                            Text(action.title)
                            Spacer()
                            Text(action.identifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                selectedAction = action
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    notificationManager.customActions.removeAll { $0.id == action.id }
                                    notificationManager.configureNotificationCategories()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        withAnimation {
                            notificationManager.customActions.remove(atOffsets: indexSet)
                            notificationManager.configureNotificationCategories()
                        }
                    }
                }
                
                Section {
                    Button("Add Custom Action") {
                        showingAddAction = true
                    }
                }
            }
            .navigationTitle("Notification Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddAction) {
                NavigationStack {
                    AddActionView(
                        onSave: { action in
                            withAnimation {
                                notificationManager.customActions.append(action)
                                notificationManager.configureNotificationCategories()
                                showingAddAction = false
                            }
                        }
                    )
                }
            }
            .sheet(item: $selectedAction) { action in
                NavigationStack {
                    EditActionView(
                        action: action,
                        onSave: { updatedAction in
                            withAnimation {
                                if let index = notificationManager.customActions.firstIndex(where: { $0.id == action.id }) {
                                    notificationManager.customActions[index] = updatedAction
                                    notificationManager.configureNotificationCategories()
                                }
                                selectedAction = nil
                            }
                        }
                    )
                }
            }
        }
    }
}

struct AddActionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var identifier = ""
    @State private var style: NotificationManager.ActionStyle = .default
    
    let onSave: (NotificationManager.NotificationAction) -> Void
    
    var body: some View {
        Form {
            Section(header: Text("Action Details")) {
                TextField("Action Title", text: $title)
                TextField("Unique Identifier", text: $identifier)
                Picker("Action Style", selection: $style) {
                    ForEach(NotificationManager.ActionStyle.allCases, id: \.self) { style in
                        Text(style.description).tag(style)
                    }
                }
            }
        }
        .navigationTitle("Add Action")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(NotificationManager.NotificationAction(
                        title: title,
                        identifier: identifier,
                        style: style
                    ))
                }
                .disabled(title.isEmpty || identifier.isEmpty)
            }
        }
    }
}

struct EditActionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let action: NotificationManager.NotificationAction
    @State private var title: String
    @State private var identifier: String
    @State private var style: NotificationManager.ActionStyle
    
    let onSave: (NotificationManager.NotificationAction) -> Void
    
    init(action: NotificationManager.NotificationAction, onSave: @escaping (NotificationManager.NotificationAction) -> Void) {
        self.action = action
        self.onSave = onSave
        
        _title = State(initialValue: action.title)
        _identifier = State(initialValue: action.identifier)
        _style = State(initialValue: action.style)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Action Details")) {
                TextField("Action Title", text: $title)
                TextField("Unique Identifier", text: $identifier)
                Picker("Action Style", selection: $style) {
                    ForEach(NotificationManager.ActionStyle.allCases, id: \.self) { style in
                        Text(style.description).tag(style)
                    }
                }
            }
        }
        .navigationTitle("Edit Action")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(NotificationManager.NotificationAction(
                        id: action.id,
                        title: title,
                        identifier: identifier,
                        style: style
                    ))
                }
                .disabled(title.isEmpty || identifier.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationActionsView()
    }
}
