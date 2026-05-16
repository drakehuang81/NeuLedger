// Features/Sources/Features/CarrierManagement/CarrierManagementView.swift
import Common
import ComposableArchitecture
import CoreImage
import CoreImage.CIFilterBuiltins
import Domain
import SwiftUI
import UIKit

public struct CarrierManagementView: View {
    @Bindable var store: StoreOf<CarrierManagementFeature>

    public init(store: StoreOf<CarrierManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)
                .ignoresSafeArea()

            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.carriers.isEmpty {
                    emptyState
                } else {
                    carrierList
                }
            }
        }
        .navigationTitle(String(localized: "carrier_management_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .sheet(item: $store.scope(state: \.addEdit, action: \.addEdit)) { addEditStore in
            AddEditCarrierView(store: addEditStore)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "creditcard.and.123",
            title: String(localized: "carrier_empty_state"),
            description: String(localized: "carrier_empty_state_desc"),
            actionTitle: String(localized: "carrier_add_button")
        ) {
            store.send(.addTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Carrier List

    private var carrierList: some View {
        ScrollView {
            VStack(spacing: 10) {
                hintCard
                carriersSection
                footerHint
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Hint Card

    private var hintCard: some View {
        GlassContainer(cornerRadius: 16, padding: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.Design.accentOrange.opacity(0.13))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Design.accentOrange)
                }
                .flexibleFrame(width: 28, height: 28, alignment: .center)

                Text(String(localized: "carrier_management_hint"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Design.textSecondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Carriers Section

    private var carriersSection: some View {
        GlassContainer(cornerRadius: 18, padding: 4) {
            VStack(spacing: 0) {
                ForEach(Array(store.carriers.enumerated()), id: \.element.id) { index, carrier in
                    carrierRow(carrier)
                    if index < store.carriers.count - 1 && store.expandedCarrierId != carrier.id {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
        }
    }

    // MARK: - Carrier Row

    @ViewBuilder
    private func carrierRow(_ carrier: Carrier) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row header
            Button {
                let _ = withAnimation(.easeInOut(duration: 0.2)) {
                    store.send(.carrierRowTapped(carrier.id))
                }
            } label: {
                HStack(spacing: 12) {
                    // Icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(carrierColor(carrier.type))
                            .frame(width: 40, height: 40)
                        Image(systemName: carrierIcon(carrier.type))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(carrier.name)
                            .font(Font.Design.body.weight(.semibold))
                            .foregroundStyle(Color.Design.textPrimary)
                        Text(carrier.barcode)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.Design.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Image(systemName: store.expandedCarrierId == carrier.id
                          ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Design.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    store.send(.editTapped(carrier))
                } label: {
                    Label(String(localized: "common_edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    store.send(.deleteTapped(carrier.id))
                } label: {
                    Label(String(localized: "common_delete"), systemImage: "trash")
                }
            }

            // Expanded barcode + QR detail
            if store.expandedCarrierId == carrier.id {
                expandedDetail(carrier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Expanded Detail

    @ViewBuilder
    private func expandedDetail(_ carrier: Carrier) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .padding(.horizontal, 14)

            // Barcode row with copy + edit buttons
            HStack {
                Text(carrier.barcode)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.Design.textPrimary)
                    .tracking(0.5)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        store.send(.editTapped(carrier))
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.Design.accentOrange.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.Design.accentOrange)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIPasteboard.general.string = carrier.barcode
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.Design.accentOrange.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.Design.accentOrange)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            // Barcode (Code 128)
            if let barcodeImage = generateBarcode(from: carrier.barcode) {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Footer Hint

    private var footerHint: some View {
        Text(String(localized: "carrier_management_swipe_hint"))
            .font(.system(size: 11))
            .foregroundStyle(Color.Design.textSecondary)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func carrierIcon(_ type: CarrierType) -> String {
        switch type {
        case .phoneBarcodeCarrier: return "iphone"
        case .citizenDigitalCertificate: return "creditcard"
        }
    }

    private func carrierColor(_ type: CarrierType) -> Color {
        switch type {
        case .phoneBarcodeCarrier: return Color.Design.accentOrange
        case .citizenDigitalCertificate: return Color(red: 0.37, green: 0.36, blue: 0.90)
        }
    }

    // MARK: - Barcode Generation (Code 128)

    private static let ciContext = CIContext()

    private func generateBarcode(from string: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        guard let data = string.data(using: .ascii) else { return nil }
        filter.message = data
        filter.quietSpace = 10
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 3.0, y: 3.0))
        guard let cgImage = Self.ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Flexible Frame Helper

private extension View {
    func flexibleFrame(width: CGFloat, height: CGFloat, alignment: Alignment = .center) -> some View {
        self.frame(width: width, height: height, alignment: alignment)
    }
}

#Preview {
    NavigationStack {
        CarrierManagementView(
            store: Store(initialState: CarrierManagementFeature.State()) {
                CarrierManagementFeature()
            }
        )
    }
}
