Only section where you need to make changes is "# === Configuration ===" section.

# === Configuration ===
$wallet        		= "yourwallet" // your wallet where node rewards later will go
$email         		= "youremail"  // your email that is later found in config.yaml file
$externalIP    		= "yourIP"     // external IP aadress
$portStart     		= 28970        // default node port is 28967, i started from 28970, since I already have nodes created by other means!
$dashboardStart		= 14005        // default 14002, for dashboard page!
$privatePortStart	= 7780         // default 7778

$nodes = @(	@{Drive="S:"; Folder="StorjNode01"; Name="Node01"; Space=500; Auth="youremail@gmail.com:yourtoken"},
			  @{Drive="M:"; Folder="StorjNode02"; Name="Node02"; Space=500; Auth="youremail@gmail.com:yourtoken"},
			  @{Drive="N:"; Folder="StorjNode03"; Name="Node03"; Space=500; Auth="youremail@gmail.com:yourtoken"}
)

// Drive="S:"                             // drive letter S in my case
// Folder="StorjNode01"                   // main folder in that drive
// Name="Node01"                          // later can be seen under the service list
// Space=500                              // how much space is reserved for the node, in GB, i had 500GB!
// Auth="youremail@gmail.com:yourtoken"   // get your token: https://storj.dev/node/get-started/auth-token

// after that is correctly filled out and the script runs without errors, you only need to set up your router ports!
