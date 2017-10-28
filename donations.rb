require 'httparty'
require 'time'

@latest = 0
@participantIDs = []

pass = ENV['TWITCH_PASS']
nick = ENV['TWITCH_USER']
channel = ENV['TWITCH_CHANNEL']

interval = ENV['EXTRA_LIFE_INTERVAL']
participantID = ENV['EXTRA_LIFE_PARTICIPANT']
teamID = ENV['EXTRA_LIFE_TEAM']

# Get new donations for a single participant
def getSingleParticipantDonations(id)
	# Get all donations made to this participant
        url = "https://www.extra-life.org/index.cfm?fuseaction=donorDrive.participantDonations&participantID=#{id}&format=json"
        result = HTTParty.get(url)

	# Get only donations that happened after the @latest donation
	newDonations = result.select { |x| Time.parse(x['createdOn']).to_i > @latest }
	return newDonations.sort_by { |x| x["createdOn"] }
end

# Get new donations from all participants in a team
def getNewTeamDonations(teamID)
	# Get list of team members
	if @participantIDs.empty?
		puts "Getting participant IDs..."
		url = "https://www.extra-life.org/index.cfm?fuseaction=donorDrive.teamParticipants&teamID=#{teamID}&format=json"
		result = HTTParty.get(url)
		@participantIDs = result.map{ |x| x['participantID']}
	end

	newDonations = []

	@participantIDs.each do |id|
		newDonations.concat getSingleParticipantDonations(id)
	end

	return newDonations.sort_by { |x| x["createdOn"] }
end

# Check if env variables are properly set
if interval.nil? || (!interval.to_i.is_a? Integer)
        puts "Error: $EXTRA_LIFE_INTERVAL must be an integer value"
        exit(1)
end

if (participantID.nil? && teamID.nil?) || (!participantID.nil? && !teamID.nil?)
        puts "$EXTRA_LIFE_PARTICIPANT or $EXTRA_LIFE_TEAM must be defined, but not both"
        exit(1)
end

if (pass.nil? || nick.nil? || channel.nil?)
	puts "$TWITCH_PASS, $TWITCH_USER, and $TWITCH_CHANNEL must be defined."
end

while true
	puts "Latest: #{@latest}"

	donations = teamID.nil? ? getSingleParticipantDonations(participantID) : getNewTeamDonations(teamID)

	if !donations.empty?
		donations.each do |d|
			if d['donorName'].nil?
				message = "Anonymous just donated#{d['donationAmount'].nil? ? '' : " $%.2f" % d['donationAmount']}!!"
			else
				message = "#{d['donorName']} just donated#{d['donationAmount'].nil? ? '' : " $%.2f" % d['donationAmount']}!! Thank you so much, #{d['donorName'].split(' ')[0]}!!"
			end

			puts message

			# Send message to Twitch chat!!
			`echo 'PASS #{pass}\nNICK #{nick.downcase}\nJOIN #{channel}\nPRIVMSG ##{channel} :#{message}\nQUIT\n' | nc irc.chat.twitch.tv 6667`
			sleep 1
		end

		@latest = Time.parse(donations.last['createdOn']).to_i
		puts "New latest: #{@latest}"
	end
	sleep interval.to_i
end
