
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
            setupCaptureSession()
        }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession = AVCaptureSession()
            
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                print("No audio device available")
                return
            }
            
            do {
                self.audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                if self.captureSession!.canAddInput(self.audioDeviceInput!) {
                    self.captureSession!.addInput(self.audioDeviceInput!)
                    print("Added audio input: \(audioDevice.localizedName)")
                }
            } catch {
                print("Failed to set audio input: \(error.localizedDescription)")
                return
            }
            
            self.audioOutput = AVCaptureAudioDataOutput()
            if let audioOutput = self.audioOutput, self.captureSession!.canAddOutput(audioOutput) {
                self.captureSession!.addOutput(audioOutput)
                print("Added audio output")
            }
        }
    }
    
    func startRecording(completion: @escaping (Bool) -> Void) {
            sessionQueue.async { [weak self] in
                guard let self = self else { return completion(false) }
                
                if self.isRecording {
                    return completion(false)
                }
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                self.recordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
//                self.recordingURL = documentsPath.appendingPathComponent("recording.m4a")
                
                guard let recordingURL = self.recordingURL else {
                    print("Failed to create recording URL")
                    return completion(false)
                }
                
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
                    } else {
                        print("Cannot add audio writer input to asset writer")
                        return completion(false)
                    }
                    
                    self.audioOutput?.setSampleBufferDelegate(self, queue: self.writerQueue)
                    
                    self.audioWriter!.startWriting()
                    self.captureSession?.startRunning()
                    self.isRecording = true
                    self.isWriterReady = false
                    self.debugBufferCount = 0
                    self.bytesWritten = 0
                    
                    print("Recording started")
                    completion(true)
                } catch {
                    print("Failed to start recording: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
        
        func stopRecording(completion: @escaping (URL?) -> Void) {
            sessionQueue.async { [weak self] in
                guard let self = self, self.isRecording else {
                    return completion(nil)
                }
                
                self.isRecording = false
                self.captureSession?.stopRunning()
                
                self.writerQueue.async {
                    self.writingSemaphore.wait()
                    self.audioWriterInput?.markAsFinished()
                    self.audioWriter?.finishWriting { [weak self] in
                        guard let self = self, let recordingURL = self.recordingURL else {
                            return completion(nil)
                        }
                        
                        print("Total audio buffers processed: \(self.debugBufferCount)")
                        print("Total bytes written: \(self.bytesWritten)")
                        
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
                            let fileSize = attributes[.size] as? Int ?? 0
                            
                            print("Recorded file size: \(fileSize) bytes")
                            
                            if fileSize > 0 {
                                completion(recordingURL)
                            } else {
                                print("Recording file is empty")
                                try? FileManager.default.removeItem(at: recordingURL)
                                completion(nil)
                            }
                        } catch {
                            print("Failed to verify recording file: \(error.localizedDescription)")
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
            }
            
            guard let audioWriterInput = audioWriterInput, audioWriterInput.isReadyForMoreMediaData else {
                print("AudioWriterInput not ready for more data")
                return
            }
            
            if audioWriterInput.append(sampleBuffer) {
                debugBufferCount += 1
                let totalSampleSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
                bytesWritten += Int64(totalSampleSize)
                if debugBufferCount % 100 == 0 {
                    print("Processed \(debugBufferCount) audio buffers, total bytes written: \(bytesWritten)")
                }
            } else {
                print("Failed to append sample buffer")
                if let error = audioWriter?.error {
                    print("AudioWriter error: \(error.localizedDescription)")
                }
            }
        }
        
        private func resetRecordingState() {
            audioWriter = nil
            audioWriterInput = nil
            recordingURL = nil
            isWriterReady = false
        }
        
    
    
}
