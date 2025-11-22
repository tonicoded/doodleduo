//
//  PremiumPaywallView.swift
//  doodleduo
//
//  Created by OpenAI Codex on 22/02/2026.
//

import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    var enforceSubscription: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    planStack
                    footer
                    legalLinks
                }
                .padding(24)
            }
            .background(
                LinearGradient(colors: [Color(#colorLiteral(red: 0.988, green: 0.933, blue: 0.949, alpha: 1)), Color(#colorLiteral(red: 0.95, green: 0.94, blue: 0.99, alpha: 1))],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
            )

            if !enforceSubscription || subscriptionManager.hasActiveSubscription {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .onChange(of: subscriptionManager.hasActiveSubscription) { _, newValue in
            if newValue {
                dismiss()
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 12)
            Text("doodleduo pro")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            if let plan = subscriptionManager.activePlan, subscriptionManager.hasActiveSubscription {
                Text("already on the \(plan.marketingName) plan.")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
            }
            Text(subscriptionManager.hasActiveSubscription ? "your farm is unlocked. keep doodling with zero limits." : "unlock unlimited love energy, exclusive skins, and priority drops together.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if enforceSubscription && !subscriptionManager.hasActiveSubscription {
                Text("your free day is over—subscribe together to keep the farm alive.")
                    .font(.subheadline.weight(.semibold))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(#colorLiteral(red: 0.999, green: 0.889, blue: 0.919, alpha: 1)))
                    )
            }
            ForEach([
                "Keep streaks alive with daily doodles & prompts",
                "Unlock rare farm skins, animated love pings & widgets",
                "Double the love energy for plants and animals",
                "Future seasonal drops & premium voice filters"
            ], id: \.self) { item in
                Label(item, systemImage: "sparkles")
                    .font(.headline)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.85))
        )
    }

    private var planStack: some View {
        VStack(spacing: 14) {
            planButton(
                plan: .yearly,
                price: subscriptionManager.displayPrice(for: .yearly),
                footer: "save over 40% • shared between both partners",
                highlight: true
            )
            planButton(
                plan: .monthly,
                price: subscriptionManager.displayPrice(for: .monthly),
                footer: "cancel anytime • keeps access for both of you",
                highlight: false
            )
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let message = subscriptionManager.lastErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 20) {
                Button("restore purchases") {
                    Task {
                        isRestoring = true
                        await subscriptionManager.restorePurchases()
                        isRestoring = false
                    }
                }
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
                .disabled(isRestoring)
                .opacity(isRestoring ? 0.6 : 1)

                if subscriptionManager.hasActiveSubscription {
                    Button("continue") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.semibold))
                }
            }
            Text("Subscriptions auto-renew until canceled. billed to your Apple ID. manage anytime in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private func planButton(plan: SubscriptionManager.Plan, price: String, footer: String, highlight: Bool) -> some View {
        Button {
            Task {
                await subscriptionManager.purchase(productID: plan.rawValue)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.marketingName)
                            .font(.headline.weight(.bold))
                        Text(plan.highlightTag.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(price)
                        .font(.title2.weight(.black))
                    if subscriptionManager.hasActiveSubscription,
                       subscriptionManager.activePlan == plan {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                }
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(highlight ? Color(#colorLiteral(red: 0.961, green: 0.784, blue: 0.863, alpha: 1)) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(highlight ? Color(#colorLiteral(red: 0.868, green: 0.4, blue: 0.545, alpha: 1)) : Color.black.opacity(0.08), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.purchaseInFlightProductID == plan.rawValue)
        .opacity(subscriptionManager.purchaseInFlightProductID == plan.rawValue ? 0.6 : 1)
    }

    private var legalLinks: some View {
        VStack(spacing: 4) {
            Divider()
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: LegalLinks.privacy)
                    .underline()
                Link("Terms of Service", destination: LegalLinks.terms)
                    .underline()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
