# Playlist Add Files and Folders Feature

## Overview
Complete implementation of adding files and folders to playlists with support for:
- Adding individual audio files
- Adding individual video files
- Adding individual document files
- Adding entire folders with automatic media scanning
- Play all and shuffle play functionality

## Features Implemented

### 1. Add Files to Playlist
Users can add individual media files to playlists:
- **Audio Files**: Browse and select audio tracks to add
- **Video Files**: Browse and select videos to add
- **Document Files**: Browse and select documents (primarily PDFs) to add
- **Multi-Select**: Select multiple files at once before adding

### 2. Add Folders to Playlist
Users can add entire folders with automatic scanning:
- **Folder Browser**: Navigate through device storage directories
- **Automatic Scanning**: Folder is scanned for all supported media files
- **Batch Addition**: All found files added to playlist at once
- **Feedback**: User is shown count of files added from folder

### 3. Play All Files
- **Play All**: Start playing all files in the playlist
- **Smart Selection**: Intelligently selects video, audio, or documents based on file types
- **Sequential Playback**: Files play in order

### 4. Shuffle Play
- **Randomized Order**: Shuffles all files before playing
- **Type-Aware**: Still groups by type (videos, audio, documents)
- **Random Order**: Each shuffle play gives different order

## File Structure

### Modified Files

#### `lib/screens/playlist_detail_screen.dart`
**Major Changes:**
- Added file selection dialogs for different media types
- Added folder selection dialog with navigation
- Implemented folder scanning functionality
- Implemented play all and shuffle play
- Added multi-file selection UI

**New Components:**
1. `_FileSelectionDialog` - Reusable dialog for selecting files by type
2. `_FolderSelectionDialog` - Dialog for browsing and selecting folders

**New Methods:**
- `_showAddMediaDialog()` - Main dialog showing add options
- `_showAddAudioDialog()` - Show audio file selection
- `_showAddVideoDialog()` - Show video file selection
- `_showAddDocumentDialog()` - Show document file selection
- `_showFileSelectionDialog()` - Generic file selection dialog
- `_showAddFolderDialog()` - Show folder selection dialog
- `_addFilesToPlaylist()` - Add selected files to playlist
- `_playAll()` - Play all files in playlist
- `_shufflePlay()` - Shuffle and play all files

## How to Use

### Adding Files to Playlist

1. **From Playlist Detail Screen:**
   - Open a playlist
   - Tap the "+" button in the app bar OR
   - Tap "Add Files" button in empty state

2. **Select File Type:**
   - Choose "Add Audio Files"
   - Choose "Add Video Files"
   - Choose "Add Document Files"
   - Choose "Add Folder"

3. **Select Files:**
   - Check boxes next to files you want to add
   - Tap "Add (n)" button to add selected files
   - Files are added to the playlist

### Adding Folders to Playlist

1. **Tap "Add Folder":**
   - Browse to the desired folder
   - Navigate through directories by tapping folder icons
   - Use "Back" button to go to previous directory
   - Tap "Select" to add all media files from folder

2. **Automatic Scanning:**
   - Folder is automatically scanned for media files
   - All supported media types are included
   - Duplicates are handled by the playlist system

### Playing Playlists

1. **Play All:**
   - Tap "Play All" button in playlist header
   - All files play sequentially by type
   - Videos play first, then audio, then documents

2. **Shuffle Play:**
   - Tap "Shuffle" button in playlist header
   - All files are randomized
   - Playback starts with shuffled order

## Technical Implementation

### File Selection Dialog
```dart
_FileSelectionDialog
- Uses appropriate provider based on media type
- Shows file list with size information
- Supports multi-select with checkboxes
- Handles loading and error states
```

### Folder Selection Dialog
```dart
_FolderSelectionDialog
- Navigates device storage directories
- Shows only directories (not files)
- Maintains navigation stack for back button
- Shows full path of selected folder
```

### Media Provider Integration
- Uses `videosProvider` for video files
- Uses `audiosProvider` for audio files
- Uses `documentsProvider` for document files
- All providers from `media_provider.dart`

### Playlist Provider Integration
- Uses `addMediaToPlaylist()` for adding files
- Updates playlist with new media IDs
- Refreshes playlist display after adding

### File Scanner Service
- Uses `scanDirectory()` to scan folders
- Returns list of `MediaFile` objects
- Handles errors gracefully

## UI/UX Features

### File Selection
- Shows file name and size
- Indicates number of selected files
- "Add (n)" button shows count
- Disabled if no files selected
- File type icons for visual clarity

### Folder Selection
- Shows current path
- Displays folder count
- Back button for navigation
- Disabled select until folder chosen
- Error handling for invalid paths

### Feedback
- Toast messages for success/error
- Shows count of files added
- Error messages for scanning failures
- Empty state messages when needed

## Error Handling

**Folder Not Found:**
- Shows error message
- Prevents selection

**No Media in Folder:**
- Shows informational message
- User can try different folder

**Permission Issues:**
- Handled by existing permission system
- User directed to enable permissions if needed

**Database Issues:**
- Errors caught and displayed
- User shown descriptive messages

## Dependencies Used

- `flutter_riverpod` - State management
- `path_provider` - Directory access
- `path` - Path utilities
- `database_service` - Media file queries

## Testing Checklist

- [ ] Add single audio file to playlist
- [ ] Add multiple audio files at once
- [ ] Add single video file to playlist
- [ ] Add multiple video files at once
- [ ] Add document files
- [ ] Add entire folder with mixed media types
- [ ] Verify Play All works with videos
- [ ] Verify Play All works with audio
- [ ] Verify Shuffle Play randomizes files
- [ ] Verify error handling for empty folders
- [ ] Verify back button in folder selection
- [ ] Verify file count display in add files
- [ ] Verify toast notifications
- [ ] Verify file removal from playlist still works

## Notes

- Files are stored by ID in playlist, not by full path
- Duplicates are possible but managed by app logic
- Folder scanning is recursive by default
- System protected paths are filtered out during scanning
- All operations are asynchronous and non-blocking
- File selection dialogs use FutureProviders for data loading
