import SwiftUI

struct RaceSelectionView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var raceService: RaceService

    @State private var showAdminUpload = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if raceService.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                    Spacer()
                } else if let error = raceService.fetchError {
                    Spacer()
                    errorView(message: error)
                    Spacer()
                } else {
                    raceList
                }
            }
        }
        .task { await raceService.fetchRaces() }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAdminUpload) {
            AdminUploadView()
                .environmentObject(raceService)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RaceVisionAR")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Select a race to begin scanning")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            HStack(spacing: 10) {
                if authService.isAdmin {
                    Button { showAdminUpload = true } label: {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.green.opacity(0.9))
                            .frame(width: 38, height: 38)
                            .background(Color(white: 0.18), in: Circle())
                    }
                }
                Button {
                    try? authService.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 38, height: 38)
                        .background(Color(white: 0.18), in: Circle())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    // MARK: - Race list

    private var raceList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(raceService.races) { race in
                    NavigationLink(value: race) {
                        RaceRow(race: race)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .refreshable { await raceService.fetchRaces() }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") {
                Task { await raceService.fetchRaces() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.green)
        }
    }
}

// MARK: - Race row

private struct RaceRow: View {
    let race: Race

    private var accentColor: Color { race.isTestRace ? .orange : .green }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: race.isTestRace ? "flask.fill" : "flag.checkered")
                    .font(.system(size: 18))
                    .foregroundStyle(accentColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(race.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    if race.isTestRace {
                        Text("TEST")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }

                if race.isTestRace {
                    Text("For bib testing in any environment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    HStack(spacing: 6) {
                        if let date = race.formattedDate {
                            Text(date)
                        }
                        if let location = race.location, !location.isEmpty {
                            if race.formattedDate != nil { Text("·").foregroundStyle(.white.opacity(0.25)) }
                            Text(location)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            race.isTestRace ? Color.orange.opacity(0.25) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    NavigationStack {
        RaceSelectionView()
            .environmentObject(AppModel())
            .environmentObject(AuthService())
            .environmentObject({
                let s = RaceService()
                s.races = [
                    Race(id: "test", name: "Test Bibs", isTestRace: true),
                    Race(id: "boston-2026", name: "Boston Marathon 2026",
                         date: Date(), location: "Boston, MA", status: .active),
                ]
                return s
            }())
    }
}
