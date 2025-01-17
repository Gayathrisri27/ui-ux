//
//  ColorViewController.swift
//  Zedit-UIKit
//
//  Created by Vinay Rajan on 10/11/24.
//

import UIKit
import AVFoundation
import AVKit
import CoreImage

class ColorViewController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet weak var videoPlayer: UIView!
    @IBOutlet weak var colorVideoPlayer: UIView!
    
    @IBOutlet weak var videoSelectorButton: UIButton!
    
    @IBOutlet weak var redSlider: UISlider!
    @IBOutlet weak var redLabel: UILabel!
    @IBOutlet weak var greenSlider: UISlider!
    @IBOutlet weak var greenLabel: UILabel!
    @IBOutlet weak var blueSlider: UISlider!
    @IBOutlet weak var blueLabel: UILabel!
    @IBOutlet weak var contrastSlider: UISlider!
    @IBOutlet weak var contrastLabel: UILabel!
    
    var projectNameColorGrade = String()
    @IBOutlet weak var applyButton: UIButton!
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var colorPlayerLayer: AVPlayerLayer?
    private var asset: AVAsset?
    private var context: CIContext?
    private var videoList: [URL] = []
    
    private var timeObserverToken: (observer: Any, player: AVPlayer)?
    private var isNavigatingBack = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideoPlayers()
        setupSliders()
        setupNavigationBar()
        
        context = CIContext(options: nil)
        
        if let videos = fetchVideos() {
            videoList = videos
            setupVideoSelector()
            if !videos.isEmpty {
                loadVideo(url: videos[0])
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        [videoPlayer, colorVideoPlayer].forEach { view in
            view?.layer.cornerRadius = 10
            view?.layer.borderColor = UIColor.lightGray.cgColor
            view?.layer.borderWidth = 1
        }
        
        videoSelectorButton.layer.cornerRadius = 8
        videoSelectorButton.setTitle("Select Video", for: .normal)
        videoSelectorButton.backgroundColor = UIColor.systemBlue
        videoSelectorButton.setTitleColor(.white, for: .normal)
        videoSelectorButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        
        applyButton.layer.cornerRadius = 8
        applyButton.backgroundColor = UIColor.systemGreen
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        applyButton.setTitle("Apply Changes", for: .normal)
    }
    
    private func setupNavigationBar() {
        navigationController?.delegate = self
        navigationItem.hidesBackButton = true
        let backButton = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backButtonTapped))
        navigationItem.leftBarButtonItem = backButton
    }
    
    @objc func backButtonTapped() {
        let alert = UIAlertController(
            title: "Confirm Navigation",
            message: "Are you sure you want to go back? Unsaved changes may be lost.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
            self.isNavigatingBack = true
            self.navigationController?.popViewController(animated: true)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        present(alert, animated: true)
    }
    
    private func setupSliders() {
        configureSlider(redSlider, label: redLabel, text: "Red", minValue: 0, maxValue: 200, defaultValue: 100)
        configureSlider(greenSlider, label: greenLabel, text: "Green", minValue: 0, maxValue: 200, defaultValue: 100)
        configureSlider(blueSlider, label: blueLabel, text: "Blue", minValue: 0, maxValue: 200, defaultValue: 100)
        configureSlider(contrastSlider, label: contrastLabel, text: "Contrast", minValue: 0, maxValue: 150, defaultValue: 50)
    }
    
    private func configureSlider(_ slider: UISlider, label: UILabel, text: String, minValue: Float, maxValue: Float, defaultValue: Float) {
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = defaultValue
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        label.text = "\(text): \(defaultValue)"
    }
    
    private func setupVideoPlayers() {
        let originalPlayer = AVPlayerViewController()
        originalPlayer.view.frame = videoPlayer.bounds
        videoPlayer.addSubview(originalPlayer.view)
        addChild(originalPlayer)
        originalPlayer.didMove(toParent: self)
        playerViewController = originalPlayer
        
        colorPlayerLayer = AVPlayerLayer()
        colorPlayerLayer?.videoGravity = .resizeAspect
        colorPlayerLayer?.frame = colorVideoPlayer.bounds
        if let colorLayer = colorPlayerLayer {
            colorVideoPlayer.layer.addSublayer(colorLayer)
        }
    }
    
    private func loadVideo(url: URL) {
        asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(url: url)
        let mainPlayer = AVPlayer(playerItem: playerItem)
        playerViewController?.player = mainPlayer
        setupColorAdjustedVideo(with: url)
        mainPlayer.play()
        addPeriodicTimeObserver()
    }
    
    private func setupColorAdjustedVideo(with url: URL) {
        guard let asset = AVAsset(url: url) as? AVURLAsset else { return }
        let composition = AVMutableComposition()
        let videoTracks = asset.tracks(withMediaType: .video)
        for assetTrack in videoTracks {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: assetTrack.trackID) else { continue }
            do {
                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: asset.duration),
                    of: assetTrack,
                    at: .zero)
            } catch {
                print("Error inserting track: \(error)")
            }
        }
        
        let videoComposition = AVMutableVideoComposition(asset: asset) { [weak self] request in
            guard let self = self else { return }
            
            let image = request.sourceImage
            
            let colorKernel = """
                 kernel vec4 colorAdjust(__sample s, float redScale, float greenScale, float blueScale, float contrast) {
                     vec4 color = s.rgba;
                     color.r *= redScale;
                     color.g *= greenScale;
                     color.b *= blueScale;
             
                     float factor = (contrast * 2.0) - 1.0;
                     vec4 mean = vec4(0.5, 0.5, 0.5, 0.5);
                     color = mix(mean, color, 1.0 + factor);
             
                     return clamp(color, vec4(0.0), vec4(1.0));
                 }
             """
            
            guard let kernel = CIColorKernel(source: colorKernel) else { return }
            
            let redScale = self.redSlider.value / 100.0
            let greenScale = self.greenSlider.value / 100.0
            let blueScale = self.blueSlider.value / 100.0
            let contrastScale = self.contrastSlider.value / 100.0
            
            if let outputImage = kernel.apply(extent: image.extent,
                                              arguments: [image, redScale, greenScale, blueScale, contrastScale]) {
                request.finish(with: outputImage, context: self.context)
            } else {
                request.finish(with: image, context: self.context)
            }
        }
        
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition
        
        let colorPlayer = AVPlayer(playerItem: playerItem)
        colorPlayerLayer?.player = colorPlayer
        
        colorPlayer.rate = playerViewController?.player?.rate ?? 1.0
    }
    
    private func addPeriodicTimeObserver() {
        if let token = timeObserverToken {
            token.player.removeTimeObserver(token.observer)
            timeObserverToken = nil
        }
        
        let interval = CMTime(seconds: 0.03, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        if let player = playerViewController?.player {
            let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                self?.colorPlayerLayer?.player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            timeObserverToken = (observer: observer, player: player)
        }
    }
    
    @objc private func sliderValueChanged() {
        updateColorLabels()
        if let url = playerViewController?.player?.currentItem?.asset as? AVURLAsset {
            setupColorAdjustedVideo(with: url.url)
        }
    }
    
    private func updateColorLabels() {
        redLabel.text = String(format: "Red: %.1f %%", redSlider.value)
        greenLabel.text = String(format: "Green: %.1f %%", greenSlider.value)
        blueLabel.text = String(format: "Blue: %.1f %%", blueSlider.value)
        contrastLabel.text = String(format: "Contrast: %.1f %%", contrastSlider.value)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerViewController?.view.frame = videoPlayer.bounds
        colorPlayerLayer?.frame = colorVideoPlayer.bounds
    }
    
    private func fetchVideos() -> [URL]? {
        guard let project = getProjects(ProjectName: projectNameColorGrade) else {
            print("Failed to get project")
            return nil
        }
        return project.videos
    }
    
    private func setupVideoSelector() {
        videoSelectorButton.isEnabled = !videoList.isEmpty
        let menuChildren = videoList.map { video in
            UIAction(title: video.lastPathComponent, handler: { _ in
                self.loadVideo(url: video)
            })
        }
        videoSelectorButton.menu = UIMenu(options: .displayInline, children: menuChildren)
        videoSelectorButton.showsMenuAsPrimaryAction = true
    }
    
    private func getProjects(ProjectName: String) -> Project? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access directory")
            return nil
        }
        
        let projectsDirectory = documentsDirectory.appendingPathComponent(ProjectName)
        guard fileManager.fileExists(atPath: projectsDirectory.path) else {
            print("Folder does not exist")
            return nil
        }
        
        do {
            let videoFiles = try fileManager.contentsOfDirectory(at: projectsDirectory, includingPropertiesForKeys: nil, options: [])
                .filter { ["mp4", "mov", "m4v", "avi", "mkv"].contains($0.pathExtension.lowercased()) }
            return Project(name: ProjectName, videos: videoFiles)
        } catch {
            print("Failed to fetch files: \(error)")
            return nil
        }
    }
    
    @IBAction func applyChanges(_ sender: UIButton) {
        guard let asset = asset,
              let url = (asset as? AVURLAsset)?.url else { return }
        
        let composition = AVMutableComposition()
        
        // Handle all video
    }
}
