import SwiftUI

struct MemoListTopBarView: View {
    let isEmpty: Bool
    let isEditMode: Bool
    let onToggleEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if !isEmpty {
                Button(action: onToggleEdit) {
                    if isEditMode {
                        Text("Cancel")
                            .fontWeight(.regular)
                    } else {
                        Image(systemName: "square.and.pencil")
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isEditMode)
            }
        }
    }
}

#Preview {
    MemoListTopBarView(isEmpty: false, isEditMode: false) {}
}

