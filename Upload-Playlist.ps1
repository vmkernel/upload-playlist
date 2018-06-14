# This script parses AIMP playlist and copy all tracks (with specific file name format) from the list to a specified folder
# © Aleksey Ivanov, 2018

function Import-AimpPlaylist {
    [CmdletBinding()]
    param (
        [parameter( 
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [System.String] $Path
    )
    
    begin {
        $strContentSectioMarker = '#-----CONTENT-----#';
        $strPlayListItemsHeader = "FilePath|Title|Artist|Album|AlbumArtist|Genre|Year|Track|Disk|Composer|Publiser|BitRate|Chanels|Frequency|DurationMs|SizeBytes|Unknown1|Unknown2|Unknown3|Unknown4|Unknown5";
    }

    process{
        $arrTracks = Get-Content -Path $strPlayListPath -Encoding Unicode; # Loading playlist
        
        $bContentSection = $false; # We're in content section of the playlist
        $arrPlayTracks = @(); # Actual tracks from the playlist
        $arrPlayTracks += $strPlayListItemsHeader; # Initializing tracklist CSV header

        for ( $idx = 0; $idx -lt $arrTracks.Count; $idx++ ) { # Playlist line processing
            if ( $bContentSection ) { # Skipping until content section starts
                if ( $arrTracks[$idx] -match "^(\+|\-).+" ) { # Skipping playlist folder groups
                    continue;
                }
                $arrPlayTracks += $arrTracks[$idx];
            }
            
            if ( [System.String]::Compare( $arrTracks[$idx], $strContentSectioMarker, $true ) -eq 0 ) { # Scanning lines for content section start marker
                $bContentSection = $true;
                continue;
            }
        }

        $strTemporaryFilePath = [System.IO.Path]::GetTempFileName(); # Temporary file path
        $arrPlayTracks | Out-File -FilePath $strTemporaryFilePath -Encoding Unicode -Force -Width ([System.Int32]::MaxValue); # Exporting resultant file as a CSV file
        $arrTracks = Import-Csv -Delimiter '|' -Path $strTemporaryFilePath; # Loading exported CSV
        Remove-Item -Path $strTemporaryFilePath -ErrorAction SilentlyContinue; # Removing temporary file

        return $arrTracks;
    }

    end {}
}

$strPlayListPath = 'C:\Users\Aleksey\AppData\Roaming\AIMP\PLS\H__ (2).aimppl4';
$arrTracks = Import-AimpPlaylist -Path $strPlayListPath;

$strOutputFolderPath = 'D:\tmp\music'

for ( $idx = 0; $idx -lt $arrTracks.Count; $idx++ ) {
    
    # Checking path to artist folder
    $strArtist = ($arrTracks[$idx].Artist).Replace( '/', ' ').Replace( '\', ' ' );
    $strDestinationFolder = "$strOutputFolderPath\$strArtist";
    if ( -not [System.IO.Directory]::Exists( $strDestinationFolder ) ) {
        New-Item -ItemType Directory -Path "$strDestinationFolder";
    }

    $iDisk = 1;
    if ( $arrTracks[$idx].Disk -ne $null ) {
        $iDisk = [System.Convert]::ToInt32($arrTracks[$idx].Disk);
    } 

    if ( $iDisk -gt 1 ) { # In case of more than one disks in the album
        # "<Year> <Disk><Track>.<Title>.mp3" (eg.: 2004 202.Wish I Had Angel (Instrumental).mp3)    
        $strDestinationFileName = [System.String]::Format( "{0:0000} {1}{2:00}.{3}.mp3", $strFileNameFormat,  $arrTracks[$idx].Year, $arrTracks[$idx].Track, $arrTracks[$idx].Title );    

    } else {
        # "<Year> <Track>.<Title>.mp3" (eg.: 2004 02.Wish I Had Angel.mp3)
        $strDestinationFileName = [System.String]::Format( "{0:0000} {1:00}.{2}.mp3", $strFileNameFormat, $arrTracks[$idx].Year, $arrTracks[$idx].Track, $arrTracks[$idx].Title );
    }
    
    Copy-Item -Path ($arrTracks[$idx].FilePath) -Destination "$strDestinationFolder\$strDestinationFileName" -WhatIf
}