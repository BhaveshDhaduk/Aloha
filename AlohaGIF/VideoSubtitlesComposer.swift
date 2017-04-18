//
//  VideoSubtitlesComposer.swift
//  AlohaGIF
//
//  Created by Michal Pyrka on 18/04/2017.
//  Copyright © 2017 Michal Pyrka. All rights reserved.
//

import UIKit
import AVFoundation

enum VideoCompositionError: Error {
    case noAudio
    case noVideo
}

struct VideoSubtitlesComposer {
    
    let exportQuality = AVAssetExportPresetHighestQuality
    
    func composeVideoWithDynamicSubtitlesPromise(asset: AVAsset, speechArray: [SpeechModel?]) -> Promise<URL> {
        return Promise<URL>(work: { fulfill, reject in
            let mixComposition = AVMutableComposition()
            let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            let clipAudioTrack = asset.tracks(withMediaType: AVMediaTypeAudio).first
            let assetDuration = CMTimeRangeMake(kCMTimeZero, asset.duration)
            guard let clip = clipAudioTrack else {
                Logger.error("No audio during video/audio composition.")
                reject(VideoCompositionError.noAudio)
                return
            }
            guard let video = asset.tracks(withMediaType: AVMediaTypeVideo).first else {
                Logger.error("No video during video/audio composition.")
                reject(VideoCompositionError.noVideo)
                return
            }
            do {
                try audioTrack.insertTimeRange(assetDuration, of: clip, at: kCMTimeZero)
            } catch {
                Logger.error("No audio during video/audio composition.")
                reject(VideoCompositionError.noAudio)
                return
            }
            do {
                try videoTrack.insertTimeRange(assetDuration, of: video, at: kCMTimeZero)
            } catch {
                Logger.error("No video during video/audio composition.")
                reject(VideoCompositionError.noVideo)
                return
            }
            
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.timeRange = assetDuration
            let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            var isVideoAssetPortrait = false
            videoLayerInstruction.setTransform(video.preferredTransform, at: kCMTimeZero)
            videoLayerInstruction.setOpacity(0.0, at: asset.duration)
            mainInstruction.layerInstructions = [videoLayerInstruction]
            let mainCompositionInst = AVMutableVideoComposition()
            
            var naturalSize = CGSize.zero
            isVideoAssetPortrait = self.videoAssetOrientation(assetTrack: video).isPortrait
            if isVideoAssetPortrait {
                naturalSize = CGSize(width: video.naturalSize.height, height: video.naturalSize.width)
            } else {
                naturalSize = video.naturalSize
            }
            
            mainCompositionInst.renderSize = CGSize(width: naturalSize.width, height: naturalSize.height)
            mainCompositionInst.instructions = [mainInstruction]
            mainCompositionInst.frameDuration = CMTime(value: 1, timescale: 30)
            DynamicSubtitlesComposer().applyChangingText(to: mainCompositionInst, speechArray: speechArray, size: naturalSize)
            //TODO: name collision?
            let videoURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("finalVideo\(arc4random() % 100000).mov")
            let exportSession = AVAssetExportSession(asset: mixComposition, presetName: self.exportQuality)
            exportSession?.outputURL = videoURL
            exportSession?.outputFileType = AVFileTypeQuickTimeMovie
            exportSession?.videoComposition = mainCompositionInst
            exportSession?.shouldOptimizeForNetworkUse = true
            exportSession?.exportAsynchronously(completionHandler: {
                DispatchQueue.main.async {
                    Logger.debug("Successfully exported video with dynamic subtitles.")
                    fulfill(videoURL)
                }
            })
        })
    }
    
    private func videoAssetOrientation(assetTrack: AVAssetTrack) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        let videoTransform = assetTrack.preferredTransform
        var videoAssetOrientation = UIImageOrientation.up
        var isVideoAssetPortrait = false
        if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
            videoAssetOrientation = .right
            isVideoAssetPortrait = true
        }
        if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
            videoAssetOrientation = .left
            isVideoAssetPortrait = true
        }
        if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
            videoAssetOrientation =  .up
        }
        if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
            videoAssetOrientation = .down
        }
        
        return (videoAssetOrientation, isVideoAssetPortrait)
    }
}