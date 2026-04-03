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
        .navigationTitle(String(localized: "carrier_management_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addTapped)
                } label: {
                    Image(systemName: "plus")
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
        List {
            ForEach(store.carriers) { carrier in
                carrierSection(carrier)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(carrier.id))
                        } label: {
                            Label(String(localized: "common_delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .padding(.bottom, 100)
    }

    @ViewBuilder
    private func carrierSection(_ carrier: Carrier) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = store.send(.carrierRowTapped(carrier.id))
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(carrier.name)
                            .font(Font.Design.body)
                            .foregroundStyle(Color.Design.textPrimary)
                        Text(carrier.type.defaultName)
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.textSecondary)
                    }
                    Spacer()
                    Image(systemName: store.expandedCarrierId == carrier.id
                          ? "chevron.up" : "chevron.down")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Design.textTertiary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            // Expanded barcode detail
            if store.expandedCarrierId == carrier.id {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    // Barcode text + copy button
                    HStack {
                        Text(carrier.barcode)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = carrier.barcode
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.brandPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    // QR Code
                    if let qrImage = generateQRCode(from: carrier.barcode) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - QR Code Generation

    private static let ciContext = CIContext()

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = Self.ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
