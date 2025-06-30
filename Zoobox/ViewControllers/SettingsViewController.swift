import UIKit

protocol SettingsViewControllerDelegate: AnyObject {
    func settingsViewController(_ controller: SettingsViewController, didUpdatePreferences preferences: UserPreferences)
    func settingsViewControllerDidRequestClearCache(_ controller: SettingsViewController)
    func settingsViewControllerDidRequestAbout(_ controller: SettingsViewController)
}

class SettingsViewController: UIViewController {
    
    weak var delegate: SettingsViewControllerDelegate?
    private let userExperienceManager = UserExperienceManager.shared
    private let offlineContentManager = OfflineContentManager.shared
    private let cookieManager = CookieManager.shared
    
    private var currentPreferences: UserPreferences
    
    // MARK: - UI Components
    
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = .zooboxBackground
        return table
    }()
    
    private let sections: [SettingsSection] = [
        .general,
        .accessibility,
        .performance,
        .about
    ]
    
    // MARK: - Initialization
    
    init() {
        self.currentPreferences = UserExperienceManager.shared.currentUserPreferences
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .zooboxBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(SliderTableViewCell.self, forCellReuseIdentifier: "SliderCell")
    }
    
    // MARK: - Actions
    
    @objc private func doneButtonTapped() {
        delegate?.settingsViewController(self, didUpdatePreferences: currentPreferences)
        dismiss(animated: true)
    }
    
    private func updatePreference(_ keyPath: WritableKeyPath<UserPreferences, Bool>, value: Bool) {
        currentPreferences[keyPath: keyPath] = value
        userExperienceManager.updateUserPreferences(currentPreferences)
    }
    
    private func updatePreference(_ keyPath: WritableKeyPath<UserPreferences, Float>, value: Float) {
        currentPreferences[keyPath: keyPath] = value
        userExperienceManager.updateUserPreferences(currentPreferences)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        let row = section.rows[indexPath.row]
        
        switch row.type {
        case .switch:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            configureSwitchCell(cell, for: row)
            return cell
            
        case .slider:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderTableViewCell
            configureSliderCell(cell, for: row)
            return cell
            
        case .action:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            configureActionCell(cell, for: row)
            return cell
            
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            configureInfoCell(cell, for: row)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let section = sections[indexPath.section]
        let row = section.rows[indexPath.row]
        
        switch row.action {
        case .clearCache:
            showClearCacheAlert()
        case .about:
            delegate?.settingsViewControllerDidRequestAbout(self)
        case .none:
            break
        }
    }
}

// MARK: - Cell Configuration

extension SettingsViewController {
    private func configureSwitchCell(_ cell: SwitchTableViewCell, for row: SettingsRow) {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        
        switch row.key {
        case .hapticFeedback:
            cell.switchControl.isOn = currentPreferences.hapticFeedbackEnabled
            cell.switchControl.addTarget(self, action: #selector(hapticFeedbackChanged(_:)), for: .valueChanged)
        case .soundEffects:
            cell.switchControl.isOn = currentPreferences.soundEffectsEnabled
            cell.switchControl.addTarget(self, action: #selector(soundEffectsChanged(_:)), for: .valueChanged)
        case .autoRetry:
            cell.switchControl.isOn = currentPreferences.autoRetryEnabled
            cell.switchControl.addTarget(self, action: #selector(autoRetryChanged(_:)), for: .valueChanged)
        case .offlineMode:
            cell.switchControl.isOn = currentPreferences.offlineModeEnabled
            cell.switchControl.addTarget(self, action: #selector(offlineModeChanged(_:)), for: .valueChanged)
        case .darkMode:
            cell.switchControl.isOn = currentPreferences.darkModeEnabled
            cell.switchControl.addTarget(self, action: #selector(darkModeChanged(_:)), for: .valueChanged)
        default:
            break
        }
    }
    
    private func configureSliderCell(_ cell: SliderTableViewCell, for row: SettingsRow) {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        
        switch row.key {
        case .fontSize:
            cell.slider.minimumValue = 0.8
            cell.slider.maximumValue = 1.4
            cell.slider.value = currentPreferences.fontSize
            cell.slider.addTarget(self, action: #selector(fontSizeChanged(_:)), for: .valueChanged)
        case .animationSpeed:
            cell.slider.minimumValue = 0.5
            cell.slider.maximumValue = 2.0
            cell.slider.value = currentPreferences.animationSpeed
            cell.slider.addTarget(self, action: #selector(animationSpeedChanged(_:)), for: .valueChanged)
        default:
            break
        }
    }
    
    private func configureActionCell(_ cell: UITableViewCell, for row: SettingsRow) {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        cell.accessoryType = .disclosureIndicator
    }
    
    private func configureInfoCell(_ cell: UITableViewCell, for row: SettingsRow) {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        cell.selectionStyle = .none
        
        switch row.key {
        case .cacheSize:
            let size = offlineContentManager.getCacheSize()
            cell.detailTextLabel?.text = formatFileSize(size)
        case .cookieCount:
            let count = cookieManager.getBackupCookieCount()
            cell.detailTextLabel?.text = "\(count) cookies"
        case .version:
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                cell.detailTextLabel?.text = version
            }
        default:
            break
        }
    }
}

// MARK: - Switch Actions

extension SettingsViewController {
    @objc private func hapticFeedbackChanged(_ sender: UISwitch) {
        updatePreference(\.hapticFeedbackEnabled, value: sender.isOn)
        userExperienceManager.playHapticFeedback(.light)
    }
    
    @objc private func soundEffectsChanged(_ sender: UISwitch) {
        updatePreference(\.soundEffectsEnabled, value: sender.isOn)
        if sender.isOn {
            userExperienceManager.playSoundEffect(.success)
        }
    }
    
    @objc private func autoRetryChanged(_ sender: UISwitch) {
        updatePreference(\.autoRetryEnabled, value: sender.isOn)
    }
    
    @objc private func offlineModeChanged(_ sender: UISwitch) {
        updatePreference(\.offlineModeEnabled, value: sender.isOn)
    }
    
    @objc private func darkModeChanged(_ sender: UISwitch) {
        updatePreference(\.darkModeEnabled, value: sender.isOn)
        // Apply dark mode changes
        if sender.isOn {
            overrideUserInterfaceStyle = .dark
        } else {
            overrideUserInterfaceStyle = .light
        }
    }
}

// MARK: - Slider Actions

extension SettingsViewController {
    @objc private func fontSizeChanged(_ sender: UISlider) {
        updatePreference(\.fontSize, value: sender.value)
    }
    
    @objc private func animationSpeedChanged(_ sender: UISlider) {
        updatePreference(\.animationSpeed, value: sender.value)
    }
}

// MARK: - Helper Methods

extension SettingsViewController {
    private func showClearCacheAlert() {
        let alert = UIAlertController(
            title: "Clear Cache",
            message: "This will remove all cached content. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.delegate?.settingsViewControllerDidRequestClearCache(self)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

enum SettingsSection {
    case general, accessibility, performance, about
    
    var title: String {
        switch self {
        case .general: return "General"
        case .accessibility: return "Accessibility"
        case .performance: return "Performance"
        case .about: return "About"
        }
    }
    
    var footer: String? {
        switch self {
        case .general: return "Configure basic app settings and preferences."
        case .accessibility: return "Customize the app for better accessibility."
        case .performance: return "Adjust performance and caching settings."
        case .about: return "App information and version details."
        }
    }
    
    var rows: [SettingsRow] {
        switch self {
        case .general:
            return [
                SettingsRow(key: .hapticFeedback, title: "Haptic Feedback", subtitle: "Vibrate on interactions", type: .switch),
                SettingsRow(key: .soundEffects, title: "Sound Effects", subtitle: "Play sounds for actions", type: .switch),
                SettingsRow(key: .autoRetry, title: "Auto Retry", subtitle: "Automatically retry failed connections", type: .switch),
                SettingsRow(key: .offlineMode, title: "Offline Mode", subtitle: "Enable offline functionality", type: .switch)
            ]
        case .accessibility:
            return [
                SettingsRow(key: .fontSize, title: "Font Size", subtitle: "Adjust text size", type: .slider),
                SettingsRow(key: .animationSpeed, title: "Animation Speed", subtitle: "Control animation duration", type: .slider),
                SettingsRow(key: .darkMode, title: "Dark Mode", subtitle: "Use dark appearance", type: .switch)
            ]
        case .performance:
            return [
                SettingsRow(key: .cacheSize, title: "Cache Size", subtitle: "Current cached content", type: .info),
                SettingsRow(key: .cookieCount, title: "Saved Cookies", subtitle: "Number of backed up cookies", type: .info),
                SettingsRow(key: .clearCache, title: "Clear Cache", subtitle: "Remove all cached content", type: .action, action: .clearCache)
            ]
        case .about:
            return [
                SettingsRow(key: .version, title: "Version", subtitle: "App version", type: .info),
                SettingsRow(key: .about, title: "About Zoobox", subtitle: "Learn more about the app", type: .action, action: .about)
            ]
        }
    }
}

struct SettingsRow {
    let key: SettingsRowKey
    let title: String
    let subtitle: String
    let type: CellType
    let action: RowAction
    
    init(key: SettingsRowKey, title: String, subtitle: String, type: CellType, action: RowAction = .none) {
        self.key = key
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.action = action
    }
}

enum SettingsRowKey {
    case hapticFeedback, soundEffects, autoRetry, offlineMode, fontSize, animationSpeed, darkMode, cacheSize, clearCache, version, about, cookieCount
}

enum CellType {
    case `switch`, slider, action, info
}

enum RowAction {
    case none, clearCache, about
}

// MARK: - Custom Table View Cells

class SwitchTableViewCell: UITableViewCell {
    let switchControl = UISwitch()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryView = switchControl
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SliderTableViewCell: UITableViewCell {
    let slider = UISlider()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryView = slider
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 