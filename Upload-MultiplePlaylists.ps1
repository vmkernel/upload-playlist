# This script loads a list of playlists, destination folders and AllInOne flags from the specified CSV file and invokes Upload-Playlist cmdlet for them
# The mail puprose is to avoid manual command typing for each playlist
# © Aleksey Ivanov, 2018

. .\Upload-Playlist.ps1;

$arrPlaylists = [System.Array] (Import-Csv -Delimiter ';' -Path .\playlists.csv);

foreach ( $objPlaylist in $arrPlaylists ) {

    $bAllInOne = $false;
    try { 
        $bAllInOne = [System.Convert]::ToBoolean( $objPlaylist.AllInOne );
        if ( $bAllInOne -eq $null ) {
            throw;
        }
    } catch {
        $bAllInOne = $false;
    }

    if ( $bAllInOne ) {
        Upload-Playlist -Playlist $objPlaylist.Playlist -Destination $objPlaylist.destination -AllInOne -Verbose -PassThru;
    } else {
        Upload-Playlist -Playlist $objPlaylist.Playlist -Destination $objPlaylist.destination -Verbose -PassThru;
    }
}