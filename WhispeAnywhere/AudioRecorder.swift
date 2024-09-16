import AVFoundation
import Cocoa

class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var audioWriter: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    public private(set) var isRecording = false
    private var isWriterReady = false
    private var recordingURL: URL?
    
    private let sessionQueue = DispatchQueue(label: "SessionQueue")
    private let writerQueue = DispatchQueue(label: "WriterQueue")
    private let writingSemaphore = DispatchSemaphore(value: 0)
    
    private var debugBufferCount = 0
    private var bytesWritten: Int64 = 0
    
    override init() {
        super.init()
        Logger.log("AudioRecorder initialized")
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            Logger.log("Setting up capture session")
            self.captureSession = AVCaptureSession()
            
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                Logger.log("No audio device available")
                return
            }
            
            do {
                self.audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                if self.captureSession!.canAddInput(self.audioDeviceInput!) {
                    self.captureSession!.addInput(self.audioDeviceInput!)
                    Logger.log("Added audio input: \(audioDevice.localizedName)")
                }
            } catch {
                Logger.log("Failed to set audio input: \(error.localizedDescription)")
                return
            }
            
            self.audioOutput = AVCaptureAudioDataOutput()
            if let audioOutput = self.audioOutput, self.captureSession!.canAddOutput(audioOutput) {
                self.captureSession!.addOutput(audioOutput)
                Logger.log("Added audio output")
            }
            
            Logger.log("Capture session setup completed")
        }
    }
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return completion(false) }
            
            if self.isRecording {
                Logger.log("Recording already in progress")
                return completion(false)
            }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.recordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            
            guard let recordingURL = self.recordingURL else {
                Logger.log("Failed to create recording URL")
                return completion(false)
            }
            
            Logger.log("Starting recording to file: \(recordingURL.lastPathComponent)")
            
            do {
                self.audioWriter = try AVAssetWriter(url: recordingURL, fileType: .m4a)
                
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                    AVEncoderBitRateKey: 128000
                ]
                
                self.audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                self.audioWriterInput?.expectsMediaDataInRealTime = true
                
                if self.audioWriter!.canAdd(self.audioWriterInput!) {
                    self.audioWriter!.add(self.audioWriterInput!)
                    Logger.log("Audio writer input added to asset writer")
                } else {
                    Logger.log("Cannot add audio writer input to asset writer")
                    return completion(false)
                }
                
                self.audioOutput?.setSampleBufferDelegate(self, queue: self.writerQueue)
                
                self.audioWriter!.startWriting()
                self.captureSession?.startRunning()
                self.isRecording = true
                self.isWriterReady = false
                self.debugBufferCount = 0
                self.bytesWritten = 0
                
                Logger.log("Recording started successfully")
                completion(true)
            } catch {
                Logger.log("Failed to start recording: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isRecording else {
                Logger.log("No active recording to stop")
                return completion(nil)
            }
            
            Logger.log("Stopping recording")
            self.isRecording = false
            self.captureSession?.stopRunning()
            
            self.writerQueue.async {
                self.writingSemaphore.wait()
                self.audioWriterInput?.markAsFinished()
                self.audioWriter?.finishWriting { [weak self] in
                    guard let self = self, let recordingURL = self.recordingURL else {
                        Logger.log("Failed to finish writing audio")
                        return completion(nil)
                    }
                    
                    Logger.log("Total audio buffers processed: \(self.debugBufferCount)")
                    Logger.log("Total bytes written: \(self.bytesWritten)")
                    
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
                        let fileSize = attributes[.size] as? Int ?? 0
                        
                        Logger.log("Recorded file size: \(fileSize) bytes")
                        
                        if fileSize > 0 {
                            Logger.log("Recording completed successfully: \(recordingURL.lastPathComponent)")
                            completion(recordingURL)
                        } else {
                            Logger.log("Recording file is empty")
                            try? FileManager.default.removeItem(at: recordingURL)
                            completion(nil)
                        }
                    } catch {
                        Logger.log("Failed to verify recording file: \(error.localizedDescription)")
                        completion(nil)
                    }
                    
                    self.resetRecordingState()
                }
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        
        if !isWriterReady {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            audioWriter?.startSession(atSourceTime: timestamp)
            isWriterReady = true
            writingSemaphore.signal()
            Logger.log("Audio writer session started")
        }
        
        guard let audioWriterInput = audioWriterInput, audioWriterInput.isReadyForMoreMediaData else {
            Logger.log("AudioWriterInput not ready for more data")
            return
        }
        
        if audioWriterInput.append(sampleBuffer) {
            debugBufferCount += 1
            let totalSampleSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
            bytesWritten += Int64(totalSampleSize)
            if debugBufferCount % 1000 == 0 {
                Logger.log("Processed \(debugBufferCount) audio buffers, total bytes written: \(bytesWritten)")
            }
        } else {
            Logger.log("Failed to append sample buffer")
            if let error = audioWriter?.error {
                Logger.log("AudioWriter error: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetRecordingState() {
        Logger.log("Resetting recording state")
        audioWriter = nil
        audioWriterInput = nil
        recordingURL = nil
        isWriterReady = false
    }
}
