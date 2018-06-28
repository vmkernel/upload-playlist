# This script parses AIMP playlist and copy all tracks (with specific file name format) from the list to a specified folder
# © Aleksey Ivanov, 2018

# TODO: Add parameter "-AllInOneDirectory" to copy all track to a specified top level directory (to use with specific playlists like 'Electronic music', 'Dance music', etc...)

function Replace-SpecialSymbols {
    [CmdletBinding()]
    param (
        [parameter (
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $String
    )

    begin {
        $strSpecialSymbolsRegExFilter = "(\*|\\|/|\?|:)+"; # List of symbols that should be replaced
        $strReplacement = ' '; # Symbols that will be used for replacement
    }

    process {
        # TODO: Check the double white-spaces removal and single white-spaces trimming
        $strResult = $String -replace $strSpecialSymbolsRegExFilter, $strReplacement; # Replacing special symbols
        $strResult = $strResult.Trim(); # Trimming white-spaces
        while ( $strResult.Contains( '  ' ) ) { # Removing double white-spaces
            $strResult = $strResult.Replace( '  ', ' ' );
        }
        return $strResult;
    }

    end {}
}

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
        $arrTracks = Get-Content -Path $Path -Encoding Unicode; # Loading playlist
        
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

function Upload-Playlist {
    [CmdletBinding()]
    param(
        [Parameter( 
            Mandatory = $true, 
            ValueFromPipeline = $true )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Playlist,

        [Parameter( Mandatory = $true )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Destination
    )

    begin {
        $bStop = $false;

        if ( -not [System.IO.Directory]::Exists( $Destination ) ) {
            $objDestinationDirectory = New-Item -ItemType Directory -Force -Path $Destination;
            if ( $objDestinationDirectory -eq $null ) {
                Write-Error -Message "Can't create the specified directory" -TargetObject $Destination;
                $bStop = $true;
            }
        }
    }

    process {
        if ( -not $bStop ) {
            if ( -not [System.IO.File]::Exists( $Playlist ) ) {
                Write-Error -Message 'The specified playlist file not exists' -Category ObjectNotFound -TargetObject $Playlist;
                return $null;
            }

            $arrTracks = @();
            $arrTracks += Import-AimpPlaylist -Path $Playlist;

            for ( $idx = 0; $idx -lt $arrTracks.Count; $idx++ ) { # Checking path to artist folder
                $strArtist = Replace-SpecialSymbols -String $arrTracks[$idx].Artist;
                $strDestinationFolder = "$Destination\$strArtist";
                if ( -not [System.IO.Directory]::Exists( $strDestinationFolder ) ) {
                    New-Item -ItemType Directory -Path "$strDestinationFolder" | Out-Null;
                }

                $iDisk = 1;
                if ( -not [System.String]::IsNullOrEmpty( $arrTracks[$idx].Disk ) ) {
                    try {
                        $iDisk = [System.Convert]::ToInt32( $arrTracks[$idx].Disk );
                    } catch { 
                        # nothing to do
                    }
                } 
                
                $strTitle = Replace-SpecialSymbols -String $arrTracks[$idx].Title;
                if ( [System.String]::IsNullOrEmpty( $strTitle ) ) {
                    $strTitle = 'UNTITLED TRACK';
                }

                # TODO: Check the conversion to integer
                $iTrack = 0;
                if ( -not [System.String]::IsNullOrEmpty( $arrTracks[$idx].Track ) ) {
                    try {
                        $iTrack = [System.Convert]::ToInt32( $arrTracks[$idx].Track );
                    } catch {
                        # nothing to do
                    }
                }

                # TODO: Check the conversion to integer
                $iYear = 0;
                if ( -not [System.String]::IsNullOrEmpty( $arrTracks[$idx].Year ) ) {
                    try {
                        $iYear = [System.Convert]::ToInt32( $arrTracks[$idx].Year );
                    } catch {
                        # nothing to do
                    }
                }

                if ( $iDisk -gt 1 ) { # In case of more than one disks in the album
                    # "<Year>-<Disk><Track>-<Title>.mp3" (eg.: 2004 202.Wish I Had Angel (Instrumental).mp3)    
                    $strDestinationFileName = [System.String]::Format( "{0:0000}-{1}{2:00}-{3}.mp3", $iYear, $iDisk, $iTrack, $strTitle );    

                } else {
                    # "<Year>-<Track>-<Title>.mp3" (eg.: 2004 02.Wish I Had Angel.mp3)
                    $strDestinationFileName = [System.String]::Format( "{0:0000}-{1:00}-{2}.mp3", $iYear, $iTrack, $strTitle );
                }
                
                Copy-Item -Path ($arrTracks[$idx].FilePath) -Destination "$strDestinationFolder\$strDestinationFileName";
            }
        }
    }

    end {}
}
