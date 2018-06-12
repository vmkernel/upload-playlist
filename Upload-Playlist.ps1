# This script parses AIMP playlist and copy all tracks (with specific file name format) from the list to a specified folder
# © Aleksey Ivanov, 2018

$strPlayListPath = 'C:\Users\Aleksey\AppData\Roaming\AIMP\PLS\H__ (2).aimppl4';
$strContentSectioMarker = '#-----CONTENT-----#';
$strPlayListItemsHeader = "FilePath|Title|Artist|Album|AlbumArtist|Genre|Year|Track|Disk|Composer|Publiser|BitRate|Chanels|Frequency|DurationMs|SizeBytes|Unknown1|Unknown2|Unknown3|Unknown4|Unknown5";

# Extracting file name for CSV
$strTemporaryFileName = [System.IO.Path]::GetFileNameWithoutExtension( $strPlayListPath );
$strTemporaryFilePath = ".\$strTemporaryFileName.csv";

# Loading playlist
$arrPlaylist = Get-Content -Path $strPlayListPath -Encoding Unicode;
 
# We're in content section of the playlist
$bContentSection = $false;
# Actual tracks from the playlist
$arrPlayTracks = @();
# Initializing tracklist CSV header
$arrPlayTracks += $strPlayListItemsHeader;

# Playlist line processing
for ( $idx = 0; $idx -lt $arrPlaylist.Count; $idx++ ) {

    # Skipping until content section starts
    if ( $bContentSection ) {

        # Skipping playlist folder groups
        if ( $arrPlaylist[$idx] -match "^(\+|\-).+" ) {
            continue;
        }

        $arrPlayTracks += $arrPlaylist[$idx];
    }

    # Scanning lines for content section start marker
    if ( [System.String]::Compare( $arrPlaylist[$idx], $strContentSectioMarker, $true ) -eq 0 ) {
        $bContentSection = $true;
        continue;
    }
}

# Exporting resultant file as a CSV file
$arrPlayTracks | Out-File -FilePath ".\$strTemporaryFilePath" -Encoding Unicode -Force -Width ([System.Int32]::MaxValue)

# Loading exported CSV
$arrPlaylist = Import-Csv -Delimiter '|' -Path $strTemporaryFilePath