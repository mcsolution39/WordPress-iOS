class StatsStackViewCell: StatsBaseCell, NibLoadable {
    private typealias Style = WPStyleGuide.Stats

    @IBOutlet private(set) var stackView: UIStackView! {
        didSet {
            if FeatureFlag.statsNewAppearance.disabled {
                contentView.addTopBorder(withColor: Style.separatorColor)
                contentView.addBottomBorder(withColor: Style.separatorColor)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        Style.configureCell(self)
        stackView.removeAllSubviews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stackView.removeAllSubviews()
    }

    func insert(view: UIView, animated: Bool = true) {
        stackView.addArrangedSubview(view)
    }
}
