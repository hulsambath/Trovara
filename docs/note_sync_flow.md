# Note Synchronization Flow

The following diagram illustrates how notes and folders are synchronized between the local device and Google Drive in Trovara.

```mermaid
sequenceDiagram
    autonumber

    actor User
    participant App as GoogleDriveSyncService
    participant Drive as GoogleDriveService
    participant NoteSvc as NoteService
    participant LocalDB as Repositories (Local Base)

    User->>App: Trigger Sync (syncWithAuthentication)
    App->>Drive: Check Sign-in State & Authenticate if needed

    %% Step 1: Download
    App->>Drive: Download 'trovara_backup.json'
    Drive-->>App: Return remote JSON data

    alt Remote Data Exists
        %% Step 2a: Merge
        App->>NoteSvc: mergeWithRemoteData(remoteData)
        NoteSvc->>NoteSvc: exportAllToJson() (Get Local Data)

        NoteSvc->>NoteSvc: Merge Folders (by 'folderId' & 'updatedAt')
        NoteSvc->>NoteSvc: Merge Notes (by 'syncId', 'updatedAt', 'deletedAt')
        NoteSvc-->>App: Return mergedData

        %% Step 2b: Import to Local DB
        App->>NoteSvc: importAllFromJson(mergedData)
        NoteSvc->>LocalDB: Upsert Folders
        NoteSvc->>LocalDB: Check Tombstones & Upsert Notes
        NoteSvc->>LocalDB: Re-embed Stale Notes
        NoteSvc-->>App: Import Complete

        %% Step 2c: Trash & Permanent Deletion Reconciliation (App = GoogleDriveSyncService)
        App->>NoteSvc: reconcileTrashStateWithDrive(noteData) [per note in mergedData]
        NoteSvc->>LocalDB: Update local trash state to match Drive
        App->>NoteSvc: permanentlyDeleteNoteOnDrive(driveFileId) [per tombstoned syncId on Drive]
        NoteSvc->>Drive: permanentlyDeleteFile(driveFileId)

    else No Remote Data
        %% Initial Sync from Local to Remote
        App->>NoteSvc: exportAllToJson()
        NoteSvc-->>App: Return localData as mergedData
    end

    %% Step 3: Upload
    App->>Drive: uploadJsonToAppData('trovara_backup.json', mergedData)
    Drive-->>App: Upload Complete

    %% Step 4: Chat Sync
    App->>App: Sync Chat History

    App-->>User: Show Success/Error Toast
```

### Key Merge Resolution Rules (Git-like strategy)

1. **Identities**: Folders are matched by `folderId`. Notes are matched by `syncId`.
2. **Missing Items**: If an item exists only locally or only remotely, it is kept in the merged set.
3. **Conflict Resolution**:
   - If both exist, their `updatedAt` timestamps are compared. The newest change wins.
   - For Notes, `deletedAt` (trash state) is also checked. If the trash state differs, the most recent action (deletion vs update) determines the winner.
4. **Tombstones**: Permanently deleted notes are tracked by `deletedSyncIds` to ensure they aren't accidentally restored from an older backup on another device.
