# VoiceInk Database Reset Guide

## Overview
This guide explains how to resolve SwiftData migration errors that may occur when running VoiceInk after major schema changes.

## Common Error
```
CoreData: error: addPersistentStoreWithType:configuration:URL:options:error: returned error NSCocoaErrorDomain (134110)
CoreData: error: reason : Cannot migrate store in-place: Validation error missing attribute values on mandatory destination attribute
```

## What This Means
The existing database has old data models that can't be migrated to the new schema. This typically happens after:
- Major architectural changes
- Schema updates
- Model property changes

## Solutions

### Option 1: Automatic Reset (Recommended)
The app now automatically detects migration errors and sets a flag to reset the database on the next launch.

**What happens:**
1. App detects migration error
2. Sets `ShouldResetDatabaseForNewSchema` flag
3. On next launch, automatically deletes old database
4. Creates fresh database with new schema

### Option 2: Manual Reset via UI (Debug Mode)
In debug builds, you can manually trigger a database reset:

1. Open the Dashboard
2. Look for the "Reset DB" button (red button)
3. Click it to trigger reset on next launch
4. Restart the app

### Option 3: Command Line Reset
You can also trigger a reset via command line:

```bash
# Run the app with reset flag
open -a VoiceInk --args --reset-database

# Or if running from Xcode, add this argument to the scheme
```

### Option 4: Force Delete Database File
If all else fails, you can manually delete the database file:

1. Open Terminal
2. Navigate to: `~/Library/Application Support/com.sadiuysal.VoiceInk/`
3. Delete `default.store` file
4. Restart the app

## Database Location
The database is stored at:
```
~/Library/Application Support/com.sadiuysal.VoiceInk/default.store
```

## Development Tools
The app includes several development tools for database management:

- **DB Status**: Shows database file information and copies path to clipboard
- **Force Delete DB**: Immediately deletes database file
- **Reset Flag Indicator**: Shows when database reset is needed

## Prevention
To avoid migration issues in the future:
- Test schema changes thoroughly
- Use proper migration strategies for production releases
- Consider using the reset mechanism during development

## Notes
- Database reset will **permanently delete all existing data**
- This is typically acceptable during development
- For production, implement proper migration strategies
- The reset mechanism is designed for development/testing scenarios

## Troubleshooting
If you continue to have issues:
1. Check console logs for specific error messages
2. Verify the database file exists and is accessible
3. Ensure the app has proper permissions to access Application Support directory
4. Try running the app with `--help` flag to see available options
