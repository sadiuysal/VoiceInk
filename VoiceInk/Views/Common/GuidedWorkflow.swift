import SwiftUI

struct GuidedWorkflow: View {
    let title: String
    let description: String
    let steps: [WorkflowStep]
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStepIndex = 0
    @State private var stepResults: [String: Any] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text("\(currentStepIndex + 1) of \(steps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            
            // Progress Bar
            ProgressView(value: Double(currentStepIndex + 1), total: Double(steps.count))
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.horizontal, 24)
            
            // Current Step
            if currentStepIndex < steps.count {
                let currentStep = steps[currentStepIndex]
                currentStep.content(
                    $stepResults,
                    { result in
                        stepResults[currentStep.id] = result
                        if currentStepIndex < steps.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStepIndex += 1
                            }
                        } else {
                            onComplete()
                        }
                    },
                    {
                        if currentStepIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStepIndex -= 1
                            }
                        }
                    },
                    currentStepIndex > 0,
                    currentStepIndex == steps.count - 1
                )
                .padding(24)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            Spacer()
        }
        .frame(maxWidth: 600, maxHeight: 500)
        .background(Color(.windowBackgroundColor))
    }
}

struct WorkflowStep {
    let id: String
    let title: String
    let content: (Binding<[String: Any]>, @escaping (Any) -> Void, @escaping () -> Void, Bool, Bool) -> AnyView
}

// MARK: - Predefined Workflow Steps

struct TextInputStep: View {
    let title: String
    let placeholder: String
    let validation: (String) -> Bool
    let onNext: (String) -> Void
    let onBack: () -> Void
    let canGoBack: Bool
    let isLastStep: Bool
    
    @State private var text = ""
    @State private var isValid = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text) { newValue in
                    isValid = validation(newValue)
                }
            
            HStack(spacing: 16) {
                if canGoBack {
                    Button("Back", action: onBack)
                        .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(isLastStep ? "Complete" : "Next") {
                    onNext(text)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
    }
}

struct SelectionStep<T: Hashable>: View {
    let title: String
    let options: [T]
    let optionTitle: (T) -> String
    let optionDescription: (T) -> String
    let onNext: (T) -> Void
    let onBack: () -> Void
    let canGoBack: Bool
    let isLastStep: Bool
    
    @State private var selectedOption: T?
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    Button(action: {
                        selectedOption = option
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(optionTitle(option))
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(optionDescription(option))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedOption == option ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedOption == option ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            HStack(spacing: 16) {
                if canGoBack {
                    Button("Back", action: onBack)
                        .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(isLastStep ? "Complete" : "Next") {
                    if let selected = selectedOption {
                        onNext(selected)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedOption == nil)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension WorkflowStep {
    static func textInput(
        id: String,
        title: String,
        placeholder: String,
        validation: @escaping (String) -> Bool = { !$0.isEmpty }
    ) -> WorkflowStep {
        WorkflowStep(id: id, title: title) { stepResults, onNext, onBack, canGoBack, isLastStep in
            AnyView(
                TextInputStep(
                    title: title,
                    placeholder: placeholder,
                    validation: validation,
                    onNext: { text in onNext(text) },
                    onBack: onBack,
                    canGoBack: canGoBack,
                    isLastStep: isLastStep
                )
            )
        }
    }
    
    static func selection<T: Hashable>(
        id: String,
        title: String,
        options: [T],
        optionTitle: @escaping (T) -> String,
        optionDescription: @escaping (T) -> String
    ) -> WorkflowStep {
        WorkflowStep(id: id, title: title) { stepResults, onNext, onBack, canGoBack, isLastStep in
            AnyView(
                SelectionStep(
                    title: title,
                    options: options,
                    optionTitle: optionTitle,
                    optionDescription: optionDescription,
                    onNext: { option in onNext(option) },
                    onBack: onBack,
                    canGoBack: canGoBack,
                    isLastStep: isLastStep
                )
            )
        }
    }
}

#Preview {
    GuidedWorkflow(
        title: "Project Setup",
        description: "Configure your first project with intelligent defaults",
        steps: [
            .textInput(
                id: "project_name",
                title: "What's your project called?",
                placeholder: "Enter project name"
            ),
            .selection(
                id: "project_type",
                title: "What type of project is this?",
                options: ["Web App", "Mobile App", "Desktop App", "Library", "Other"],
                optionTitle: { $0 },
                optionDescription: { _ in "Select the most appropriate category" }
            )
        ],
        onComplete: { print("Workflow completed") },
        onCancel: { print("Workflow cancelled") }
    )
}
