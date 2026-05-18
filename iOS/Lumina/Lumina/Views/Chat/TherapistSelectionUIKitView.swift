import SwiftUI
import UIKit

struct TherapistSelectionUIKitView: UIViewControllerRepresentable {
    let sessions: [String: ChatSession]
    let onOpen: (Therapist) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpen: onOpen)
    }

    func makeUIViewController(context: Context) -> TherapistSelectionViewController {
        let controller = TherapistSelectionViewController()
        controller.coordinator = context.coordinator
        controller.configure(with: sessions)
        return controller
    }

    func updateUIViewController(_ controller: TherapistSelectionViewController, context: Context) {
        context.coordinator.onOpen = onOpen
        controller.coordinator = context.coordinator
        controller.configure(with: sessions)
    }

    final class Coordinator: NSObject {
        var onOpen: (Therapist) -> Void

        init(onOpen: @escaping (Therapist) -> Void) {
            self.onOpen = onOpen
        }
    }
}

final class TherapistSelectionViewController: UIViewController {
    var coordinator: TherapistSelectionUIKitView.Coordinator?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let heroView = TherapistSelectionHeroView()
    private var activeTherapistIDs = Set<String>()

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .luminaBackground
        view = root

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .luminaBackground
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 24, right: 16)

        root.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        rebuildContent()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        heroView.configure(topInset: view.safeAreaInsets.top)
    }

    func configure(with sessions: [String: ChatSession]) {
        activeTherapistIDs = Set(sessions.values.flatMap { [$0.therapistID, $0.id] })
        if isViewLoaded {
            rebuildContent()
        }
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { subview in
            contentStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        heroView.configure(topInset: view.safeAreaInsets.top)
        contentStack.addArrangedSubview(heroView)

        for therapist in allTherapists {
            let card = TherapistSelectionCardControl()
            card.configure(
                therapist: therapist,
                isActive: activeTherapistIDs.contains(therapist.id)
            )
            card.addTarget(self, action: #selector(openTherapist(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(card)
        }
    }

    @objc private func openTherapist(_ sender: TherapistSelectionCardControl) {
        guard let therapist = sender.therapist else { return }
        coordinator?.onOpen(therapist)
    }
}

private final class TherapistSelectionHeroView: UIView {
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var topConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .luminaBackground

        eyebrowLabel.text = "AI SANCTUARY"
        eyebrowLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        eyebrowLabel.textColor = .luminaMutedForeground
        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Therapy"
        titleLabel.font = .systemFont(ofSize: 40, weight: .heavy)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Choose a guide for the kind of support you need today."
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(eyebrowLabel)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        let topConstraint = eyebrowLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12)
        self.topConstraint = topConstraint

        NSLayoutConstraint.activate([
            topConstraint,
            eyebrowLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            eyebrowLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            titleLabel.leadingAnchor.constraint(equalTo: eyebrowLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: eyebrowLabel.bottomAnchor, constant: 8),

            subtitleLabel.leadingAnchor.constraint(equalTo: eyebrowLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(topInset: CGFloat) {
        topConstraint?.constant = min(topInset + 10, 72)
    }
}

final class TherapistSelectionCardControl: UIControl {
    private let cardView = UIView()
    private let avatarView = UIView()
    private let initialsLabel = UILabel()
    private let nameLabel = UILabel()
    private let roleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let badgeLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))

    private(set) var therapist: Therapist?

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.16) {
                self.cardView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.985, y: 0.985)
                    : .identity
                self.cardView.alpha = self.isHighlighted ? 0.86 : 1
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(therapist: Therapist, isActive: Bool) {
        self.therapist = therapist
        let accent = UIColor(hex: therapist.accentHex)
        avatarView.backgroundColor = accent.withAlphaComponent(0.16)
        initialsLabel.text = Self.initials(from: therapist.name)
        initialsLabel.textColor = accent
        nameLabel.text = therapist.name
        roleLabel.text = therapist.role.uppercased()
        descriptionLabel.text = therapist.description
        badgeLabel.isHidden = !isActive
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .luminaCard
        cardView.layer.cornerRadius = 24
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.luminaBorder.resolvedColor(with: traitCollection).withAlphaComponent(0.7).cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.24 : 0.035
        cardView.layer.shadowRadius = 14
        cardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardView.isUserInteractionEnabled = false

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.cornerRadius = 18
        avatarView.clipsToBounds = true

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = .systemFont(ofSize: 19, weight: .heavy)
        initialsLabel.textAlignment = .center

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 19, weight: .bold)
        nameLabel.textColor = .label

        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        roleLabel.font = .systemFont(ofSize: 12, weight: .heavy)
        roleLabel.textColor = .luminaMutedForeground
        roleLabel.numberOfLines = 1

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 2

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "Active"
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = .luminaPrimary

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = .tertiaryLabel

        addSubview(cardView)
        cardView.addSubview(avatarView)
        avatarView.addSubview(initialsLabel)
        cardView.addSubview(nameLabel)
        cardView.addSubview(roleLabel)
        cardView.addSubview(descriptionLabel)
        cardView.addSubview(badgeLabel)
        cardView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 126),

            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),

            initialsLabel.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            initialsLabel.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            initialsLabel.topAnchor.constraint(equalTo: avatarView.topAnchor),
            initialsLabel.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            chevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),

            badgeLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -12),
            badgeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            roleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -14),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            descriptionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -14),
            descriptionLabel.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 8),
            descriptionLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        cardView.layer.borderColor = UIColor.luminaBorder.resolvedColor(with: traitCollection).withAlphaComponent(0.7).cgColor
        cardView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.24 : 0.035
    }

    private static func initials(from name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "Dr. ", with: "")
        let letters = cleaned
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
        return letters.isEmpty ? "AI" : letters.uppercased()
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}
