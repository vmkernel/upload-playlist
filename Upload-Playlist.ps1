# This script parses AIMP playlist and copy all tracks (with specific file name format) from the list to a specified folder
# © Aleksey Ivanov, 2018

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
        #$arrSpecialSymbols = ( # List of symbols that should be replaced
        #    '*', '\', '/', '.', '?', ':' );
        $strSpecialSymbolsRegExFilter = "(\*|\\|/|\?|:)+"; # List of symbols that should be replaced
        $strReplacement = ' '; # Symbols that will be used for replacement
    }

    process {
        #$strResult = $String;
        #foreach ( $strSymbol in $arrSpecialSymbols ) {
        #    $strResult = $strResult.Replace( $strSymbol, $strReplacement );
        #}

        $strResult = $String -replace $strSpecialSymbolsRegExFilter, $strReplacement;

        # TODO: Trim spaces from start and end of the string
        # TODO: Replace double spaces

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

            for ( $idx = 0; $idx -lt $arrTracks.Count; $idx++ ) {
                # Checking path to artist folder
                $strArtist = Replace-SpecialSymbols -String $arrTracks[$idx].Artist;
                $strDestinationFolder = "$Destination\$strArtist";
                if ( -not [System.IO.Directory]::Exists( $strDestinationFolder ) ) {
                    New-Item -ItemType Directory -Path "$strDestinationFolder" | Out-Null;
                }

                $iDisk = 1;
                if ( -not [System.String]::IsNullOrEmpty( $arrTracks[$idx].Disk ) ) {
                    $iDisk = [System.Convert]::ToInt32($arrTracks[$idx].Disk);
                } 
                
                $strTitle = Replace-SpecialSymbols -String $arrTracks[$idx].Title;
                if ( [System.String]::IsNullOrEmpty( $strTitle ) ) {
                    $strTitle = 'UNTITLED TRACK';
                }

                $strTrack = $arrTracks[$idx].Track;
                if ( [System.String]::IsNullOrEmpty( $strTrack ) ) {
                    $strTrack  = "0";
                }

                $strYear = $arrTracks[$idx].Year;
                if ( [System.String]::IsNullOrEmpty( $strYear ) ) {
                    $strYear  = "0000";
                }

                if ( $iDisk -gt 1 ) { # In case of more than one disks in the album
                    # "<Year>-<Disk><Track>-<Title>.mp3" (eg.: 2004 202.Wish I Had Angel (Instrumental).mp3)    
                    $strDestinationFileName = [System.String]::Format( "{0:0000}-{1}{2:00}-{3}.mp3", $strYear, $iDisk, $strTrack, $strTitle );    

                } else {
                    # "<Year>-<Track>-<Title>.mp3" (eg.: 2004 02.Wish I Had Angel.mp3)
                    $strDestinationFileName = [System.String]::Format( "{0:0000}-{1:00}-{2}.mp3", $strYear, $strTrack, $strTitle );
                }
                
                Copy-Item -Path ($arrTracks[$idx].FilePath) -Destination "$strDestinationFolder\$strDestinationFileName";
            }
        }
    }

    end {}
}
