# LLM.swift Integration Setup Instructions

## 1. Add LLM.swift Package Dependency

1. Open `Sonora.xcodeproj` in Xcode
2. Go to **File** → **Add Package Dependencies**
3. Enter URL: `https://github.com/eastriverlee/LLM.swift`
4. Select **Branch**: `main`
5. Click **Add Package**
6. Add `LLM` to your `Sonora` target

## 2. Add New Files to Xcode Project

The following files have been created but need to be added to the Xcode project:

### Data/Services/Analysis/
- `SimpleModelDownloader.swift`
- `LlamaAnalysisService.swift`

### Presentation/Views/
- `ModelDownloadView.swift`

### Features/Settings/UI/
- `LocalAISectionView.swift`

**To add these files:**
1. In Xcode, right-click on the appropriate group folder
2. Choose **Add Files to "Sonora"**
3. Navigate to the created file and add it
4. Make sure it's added to the Sonora target

## 3. Import LLM Framework

The `LlamaAnalysisService.swift` file includes `import LLM`. Make sure this compiles after adding the package.

## 4. Test the Integration

1. Build and run the app
2. Go to **Settings** → **Local AI**
3. Toggle **"Use Local Analysis"** ON
4. Tap **"Manage Model"**
5. Download the LLaMA 3.2 3B model (~2GB)
6. Record a test memo and verify analysis works

## 5. Testing Checklist

✅ App builds successfully  
✅ LLM.swift package imports correctly  
✅ Model download UI appears in settings  
✅ Download progress works  
✅ Model stays ready after download  
✅ Local analysis toggle works  
✅ Voice memo analysis uses local model  
✅ Model unloads when app backgrounds  

## What This Gets You

- **Working local LLM** analysis in 2 hours
- **Simple download** with progress tracking
- **Model persistence** - stays loaded for session
- **Clean integration** - uses existing UI
- **Real performance data** to compare vs API

## Next Steps (Optional)

If local analysis works well, consider adding:
- Download resume capability
- Checksum validation  
- Better memory management
- Advanced error handling

But ship this MVP first to validate the concept! 🚀