################################################################################
#
# The file is part of the SIGNALduino project
# v3.5.x - https://github.com/RFD-FHEM/RFFHEM/tree/dev-r35-xFSK
#
# 2016-2019  S.Butzek, Ralf9
# 2019-2020  S.Butzek, HomeAutoUser, elektron-bbs
#
################################################################################
package lib::SD_Protocols;

use strict;
use warnings;
use Carp qw(croak carp);
use Digest::CRC;
our $VERSION = '1.01';
use Storable qw(dclone);

use Data::Dumper;

############################# package lib::SD_Protocols
#=item new($)
# This functons, will initialize the given Filename containing a valid protocolHash
# First Parameter is for filename (full or relativ path) to be loaded
# Returns string with error value or undef
# =cut
#  $id

sub new {
	my $class = shift;
	croak "Illegal parameter list has odd number of values" if @_ % 2;
	my %args = @_;
	my $self = {};

	$self->{_protocolFilename} = $args{filename} // q[];
	$self->{_protocols}        = undef;
	$self->{_filetype}         = $args{filetype} // 'PerlModule';
	$self->{_logCallback}      = undef;
	bless $self, $class;

	if ( $self->{_protocolFilename} ) {

		( $self->{_filetype} eq 'json' )
		  ? $self->LoadHashFromJson( $self->{_protocolFilename} )
		  : $self->LoadHash( $self->{_protocolFilename} );
	}
	return $self;
}

############################# package lib::SD_Protocols
#=item STORABLE_freeze()
# This function is not currently explained.
# =cut

sub STORABLE_freeze {
	my $self = shift;
	return join( q[:], ( $self->{_protocolFilename}, $self->{_filetype} ) );
}

############################# package lib::SD_Protocols
#=item STORABLE_thaw()
# This function is not currently explained.
# =cut

sub STORABLE_thaw {
	my ( $self, $cloning, $frozen ) = @_;
	( $self->{_protocolFilename}, $self->{_filetype} ) =
	  split( /:/xms, $frozen );
	$self->LoadHash();
	$self->LoadHashFromJson();
	return;
}

############################# package lib::SD_Protocols
#=item LoadHashFromJson()
# This functons, will load protocol hash from json file into a hash.
# First Parameter is for filename (full or relativ path) to be loaded
# Returns error or undef on success
# =cut
#  $id

sub LoadHashFromJson {
	my $self     = shift // carp 'Not called within an object';
	my $filename = shift // $self->{_protocolFilename};

	return if ( $self->{_filetype} ne 'json' );

	if ( !-e $filename ) {
		return qq[File $filename does not exsits];
	}

	open( my $json_fh, '<:encoding(UTF-8)', $filename )
	  or croak("Can't open \$filename\": $!\n");
	my $json_text = do { local $/ = undef; <$json_fh> };
	close $json_fh or croak "Can't close '$filename' after reading";

	use JSON;
	my $json = JSON->new;
	$json = $json->relaxed(1);
	my $ver  = $json->incr_parse($json_text);
	my $prot = $json->incr_parse();

	$self->{_protocols}        = $prot           // 'undef';
	$self->{_protocolsVersion} = $ver->{version} // 'undef';

	$self->setDefaults();
	$self->{_protocolFilename} = $filename;
	return;
}

############################# package lib::SD_Protocols, test exists
#=item LoadHash()
# This functons, will load protocol hash from perlmodule file .
# First Parameter is for filename (full or relativ path) to be loaded
# Returns error or undef on success
# =cut
#  $id

sub LoadHash {
	my $self     = shift // carp 'Not called within an object';
	my $filename = shift // $self->{_protocolFilename};

	return if ( $self->{_filetype} ne "PerlModule" );

	if ( !-e $filename ) {
		return qq[File $filename does not exists];
	}

	return $@ if ( !eval { require $filename; 1 } );
	$self->{_protocols}        = \%lib::SD_ProtocolData::protocols;
	$self->{_protocolsVersion} = $lib::SD_ProtocolData::VERSION;

	delete( $INC{$filename} ); # Unload package, because we only wanted the hash

	$self->setDefaults();
	$self->{_protocolFilename} = $filename;
	return;
}

############################# package lib::SD_Protocols, test exists
#=item protocolexists()
# This functons, will return true if the given ID exists otherwise false
# =cut
#  $id
sub protocolExists {
	my $self = shift // carp 'Not called within an object';
	my $pId= shift // carp "Illegal parameter number, protocol id was not specified";
	return exists($self->{_protocols}->{$pId});
}

############################# package lib::SD_Protocols, test exists
#=item getProtocolList()
# This functons, will return a reference to the protocol hash
# =cut
#  $id, $propertyname,
sub getProtocolList {
	my $self = shift // carp 'Not called within an object';
	return $self->{_protocols};
}

############################# package lib::SD_Protocols, test exists

=item getKeys()
This functons, will return all keys from the protocol hash

=cut

sub getKeys {
	my $self = shift // carp 'Not called within an object';
	my (@ret) = keys %{ $self->{_protocols} };
	return @ret;
}

############################# package lib::SD_Protocols, test exists
#=item checkProperty()
# This functons, will return a value from the Protocolist and check if the key exists and a value is defined optional you can specify a optional default value that will be returned
#
# returns undef if the var is not defined
# =cut
#  $id, $propertyname,$default

sub checkProperty {
	my $self      = shift // carp 'Not called within an object';
	my $id        = shift // return;
	my $valueName = shift // return;
	my $default   = shift // undef;

	return $self->{_protocols}->{$id}->{$valueName}
	  if exists( $self->{_protocols}->{$id}->{$valueName} )
	  && defined( $self->{_protocols}->{$id}->{$valueName} );
	return $default;    # Will return undef if $default is not provided
}

############################# package lib::SD_Protocols, test exists
#=item getProperty()
# This functons, will return a value from the Protocolist without any checks
#
# returns undef if the var is not defined
# =cut
#  $id, $propertyname

sub getProperty {
	my $self      = shift // carp 'Not called within an object';
	my $id        = shift // return;
	my $valueName = shift // return;

	return $self->{_protocols}->{$id}->{$valueName}
	  if ( exists $self->{_protocols}->{$id}->{$valueName} );
	return;
}

############################# package lib::SD_Protocols, test exists

=item getProtocolVersion()
This functons, will return a version value of the Protocolist

=cut

sub getProtocolVersion {
	my $self = shift // carp 'Not called within an object';
	return $self->{_protocolsVersion};
}

############################# package lib::SD_Protocols, test exists

=item setDefaults()
This functon will add common Defaults to the Protocollist

=cut

sub setDefaults {
	my $self = shift // carp 'Not called within an object';
	
	for my $id ( $self->getKeys() )
	{
		my $format = $self->getProperty($id,'format');
			
		if ( defined $format && ($format eq 'manchester' || $format =~ 'FSK') )
		{
			# Manchester defaults :
			my $cref = $self->checkProperty( $id, 'method' );
			( !defined $cref && $format eq 'manchester' )
			  ? $self->{_protocols}->{$id}->{method} =
			  \&lib::SD_Protocols::MCRAW
			  : undef;

			if ( defined $cref ) {
				$cref =~ s/^\\&//xms;
				( ref $cref ne 'CODE' )
				  ? $self->{_protocols}->{$id}->{method} = eval { \&$cref }
				  : undef;
			}
		}
		elsif ( defined( $self->getProperty( $id, 'sync' ) ) ) {

			# Messages with sync defaults :
		}
		elsif ( defined( $self->getProperty( $id, 'clockabs' ) ) ) {

			# Messages without sync defaults :
			( !defined( $self->checkProperty( $id, 'length_min' ) ) )
			  ? $self->{_protocols}->{$id}->{length_min} = 8
			  : undef;
		}
		else {

		}
	}
	return;
}

############################# package lib::SD_Protocols, test exists

=item binStr2hexStr()
This functon will convert binary string into its hex representation as string

Input:  binary string
Output:
        hex string

=cut

sub binStr2hexStr {
	my $num = shift // return;
	return if ( $num !~ /^[01]+$/xms );
	my $WIDTH = 4;
	my $index = length($num) - $WIDTH;
	my $hex   = '';
	do {
		my $width = $WIDTH;
		if ( $index < 0 ) {
			$width += $index;
			$index = 0;
		}
		my $cut_string = substr( $num, $index, $width );
		$hex = sprintf( '%X', oct("0b$cut_string") ) . $hex;
		$index -= $WIDTH;
	} while ( $index > ( -1 * $WIDTH ) );
	return $hex;
}


=item LengthInRange()
This functon checks if a given length is in range of the valid min and max length for the given protocolId

Input:  ($object,$protocolID,$message_length);

Output:
		on success array (returnCode=1, '')
		otherwise array (returncode=0,"Error message")
=cut
sub LengthInRange {
	my $self    			= shift // carp 'Not called within an object';
	my $id					= shift // carp 'protocol ID must be provided';
	my $message_length   	= shift // return (0,'no message_length provided');

	return (0,'protocol does not exists') if (!$self->protocolExists($id));
	
	if ($message_length < $self->checkProperty($id,'length_min',-1)) {
		return (0, 'message is to short');
	}
	elsif (defined $self->getProperty($id,'length_max') && $message_length > $self->getProperty($id,'length_max')) {
		return (0, 'message is to long');
	}
	return (1,q{});
}


############################# package lib::SD_Protocols, test exists

=item MCRAW()
This functon is desired to be used as a default output helper for manchester signals.
It will check for length_max and return a hex string

Input:  $object,$name,$bitData,$id,$mcbitnum

Output:
        hex string
		or array (-1,"Error message")
		
=cut

sub MCRAW {
	my ( $self, $name, $bitData, $id, $mcbitnum ) = @_;
	$self // carp 'Not called within an object';

	return (-1," message is to long") if ($mcbitnum > $self->checkProperty($id,"length_max",0) );
	return(1,binStr2hexStr($bitData)); 
}


=item mcBit2Grothe()
extract the message from the bitdata if it looks like valid data

Input:  ($object,$name,$bitData,$protocolID, optional: length $bitData);

Output:
		on success array (returnCode=1, hexData)
		otherwise array (returncode=-1,"Error message")
=cut

sub mcBit2Grothe {
	my $self    			= shift // carp 'Not called within an object' && return (0,'no object provided');
	my $name				= shift // "anonymous";
	my $bitData				= shift // carp 'bitData must be perovided' && return (0,'no bitData provided');
	my $id					= shift // carp 'protocol ID must be provided' && return (0,'no protocolId provided');;;
	my $message_length   	= shift // length $bitData;

	my $bitLength;
	
	$bitData = substr($bitData, 0, $message_length);
	my $preamble = '01000111';
	my $pos = index($bitData, $preamble);
	if ($pos < 0 || $pos > 5) {
		$self->_logging( qq[lib/mcBit2Grothe, protocol id $id, start pattern ($preamble) not found], 3 );
		return (-1,qq[Start pattern ($preamble) not found]);
	} else {
		if ($pos == 1) {		# eine Null am Anfang zuviel
			$bitData =~ s/^0//;		# eine Null am Anfang entfernen
		}
		$bitLength = length($bitData);
		my ($rcode, $rtxt) = $self->LengthInRange($id, $bitLength);
		if (!$rcode) {
			$self->_logging( qq[lib/mcBit2Grothe, protocol id $id, $rtxt], 3 );
			return (-1,qq[$rtxt]);
		}
	}
	my $hex = lib::SD_Protocols::binStr2hexStr($bitData);
	$self->_logging( q[lib/mcBit2Grothe, protocol id $id detected, $bitData ($bitLength], 4 );
	return (1,$hex); ## Return the bits unchanged in hex
}



=item mcBit2TFA()
extract the message from the bitdata if it looks like valid data

Input:  ($object,$name,$bitData,$protocolID, optional: length $bitData);

Output:
		on success array (returnCode=1, hexData)
		otherwise array (returncode=-1,"Error message")
=cut
sub mcBit2TFA {
	my $self    			= shift // carp 'Not called within an object' && return (0,'no object provided');
	my $name				= shift // "anonymous";
	my $bitData				= shift // carp 'bitData must be perovided' && return (0,'no bitData provided');
	my $id					= shift // carp 'protocol ID must be provided' && return (0,'no protocolId provided');;;
	my $mcbitnum   	= shift // length $bitData;

	my $preamble_pos;
	my $message_end;
	my $message_length;

	#if ($bitData =~ m/^.?(1){16,24}0101/)  {
	if ($bitData =~ m/(1{9}101)/xms )
	{
		$preamble_pos=$+[1];
		$self->_logging( qq[lib/mcBit2TFA, 30.3208.0 preamble_pos = $preamble_pos], 4 );
		return return (-1,q[ sync not found]) if ($preamble_pos <=0);
		my @messages;

		my $i=1;
		my $retmsg = q{};
		do
		{
			$message_end = index($bitData,'1111111111101',$preamble_pos);
			if ($message_end < $preamble_pos)
			{
				$message_end=$mcbitnum;		# length($bitData);
			}
			$message_length = ($message_end - $preamble_pos);

			my $part_str=substr($bitData,$preamble_pos,$message_length);
			$self->_logging( qq[lib/mcBit2TFA, message start($i)=$preamble_pos end=$message_end with length=$message_length], 4 );
			$self->_logging( qq[lib/mcBit2TFA, message part($i)=$part_str], 5 );

			my ($rcode, $rtxt) = $self->LengthInRange($id, $message_length);
			if ($rcode) {
				my $hex=lib::SD_Protocols::binStr2hexStr($part_str);
				push (@messages,$hex);
				$self->_logging( qq[lib/mcBit2TFA, message part($i)=$hex], 4 );
			}
			else {
				$retmsg = q[, ] . $rtxt;
			}

			$preamble_pos=index($bitData,'1101',$message_end)+4;
			$i++;
		}  while ($message_end < $mcbitnum);

		my %seen;
		my @dupmessages = map { 1==$seen{$_}++ ? $_ : () } @messages;

		return ($i,q[loop error, please report this data $bitData]) if ($i==10);
		if (scalar(@dupmessages) > 0 ) {
			$self->_logging( qq[lib/mcBit2TFA, repeated hex $dupmessages[0] found $seen{$dupmessages[0]} times"], 4 );
			return  (1,$dupmessages[0]);
		} else {
			return (-1,qq[ no duplicate found$retmsg]);
		}
	}
	return (-1,undef);
}





############################# package lib::SD_Protocols, test exists

=item registerLogCallback()

=cut

sub registerLogCallback {
	my $self     = shift // carp 'Not called within an object';
	my $callback = shift // carp 'coderef must be provided';

	( ref $callback eq 'CODE' )
	  ? $self->{_logCallback} = $callback
	  : carp 'coderef must be provided for callback';

	return;
}

############################# package lib::SD_Protocols

=item _logging()

The sub transfers the data to the sub which is referenced by the code ref.
example: $self->_logging('something happend','3')

=cut

sub _logging {
	my $self    = shift // carp 'Not called within an object';
	my $message = shift // carp 'message must be provided';
	my $level   = shift // 3;

	if ( defined $self->{_logCallback} ) {
		$self->{_logCallback}->( $message, $level );
	}
	return;
}

######################### package lib::SD_Protocols #########################
###       all functions for RAWmsg processing or module preparation       ###
#############################################################################

############################################################
# ASK/OOK method functions
############################################################

=item dec2binppari()
This sub calculated. It converts a decimal number with a width of 8 bits into binary format,
calculates the parity, appends the parity bit and returns this 9 bit.

Input:  $num
Output:
        calculated number binary with parity

=cut

sub dec2binppari {    # dec to bin . parity
	my $num    = shift // carp 'must be called with an number';
	my $parity = 0;
	my $nbin   = sprintf( "%08b", $num );
	for my $c ( split //, $nbin ) {
		$parity ^= $c;
	}
	return qq[$nbin$parity];    # bin(num) . paritybit
}


############################################################

=item Convbit2Arctec()

This sub convert 0 -> 01, 1 -> 10 to be compatible with IT Module.

Input:  @bit_msg

Output:
        converted message

=cut

sub Convbit2Arctec {
	my ( $self, undef, @bitmsg ) = @_;
	$self   // carp 'Not called within an object';
	@bitmsg // carp 'no bitmsg provided';
	my $convmsg = join( "", @bitmsg );
	my @replace = qw(01 10);

	# Convert 0 -> 01   1 -> 10 to be compatible with IT Module
	$convmsg =~ s/(0|1)/$replace[$1]/gx;
	return ( 1, split( //, $convmsg ) );
}

############################################################

=item Convbit2itv1()
This sub convert 0F -> 01 (F) to be compatible with CUL.

Input:  $msg
Output:
        converted message

=cut

sub Convbit2itv1 {
	my ( $self, undef, @bitmsg ) = @_;
	$self   // carp 'Not called within an object';
	@bitmsg // carp 'no bitmsg provided';
	my $msg = join( "", @bitmsg );

	$msg =~ s/0F/01/gsm;    # Convert 0F -> 01 (F) to be compatible with CUL
	return ( 1, split( //, $msg ) ) if ( index( $msg, 'F' ) == -1 );
	return ( 0, 0 );
}

############################################################

=item ConvHE800()

This sub checks the length of the bits.
If the length is less than 40, it adds a 0.

Input:  $name, @bit_msg

Output:
        scalar converted message on success 

=cut

sub ConvHE800 {
	my ( $self, $name, @bit_msg ) = @_;
	$self // carp 'Not called within an object';

	my $protolength = scalar @bit_msg;

	if ( $protolength < 40 ) {
		for ( my $i = 0 ; $i < ( 40 - $protolength ) ; $i++ ) {
			push( @bit_msg, 0 );
		}
	}
	return ( 1, @bit_msg );
}

############################################################

=item ConvHE_EU()
This sub checks the length of the bits.
If the length is less than 72, it adds a 0.

Input:  $name, @bit_msg
Output:
        scalar converted message on success 

=cut

sub ConvHE_EU {
	my ( $self, $name, @bit_msg ) = @_;
	my $protolength = scalar @bit_msg;

	if ( $protolength < 72 ) {
		for ( my $i = 0 ; $i < ( 72 - $protolength ) ; $i++ ) {
			push( @bit_msg, 0 );
		}
	}
	return ( 1, @bit_msg );
}

############################################################

=item ConvITV1_tristateToBit()
This sub Convert 0 -> 00, 1 -> 11, F => 01 to be compatible with IT Module.

Input:  $msg

Output:
        converted message

=cut

sub ConvITV1_tristateToBit {
	my ($msg) = @_;

	$msg =~ s/0/00/gsm;
	$msg =~ s/1/11/gsm;
	$msg =~ s/F/01/gsm;
	$msg =~ s/D/10/gsm;

	return ( 1, $msg );
}

############################################################

=item postDemo_EM()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $id,$sum,$msg
Output:
        prepares message

=cut

sub postDemo_EM {
	my $self = shift // carp 'Not called within an object';
	my ( $name, @bit_msg ) = @_;
	my $msg = join( q[], @bit_msg );
	my $msg_start = index( $msg, '0000000001' );    # find start
	$msg = substr( $msg, $msg_start + 10 );         # delete preamble + 1 bit
	my $new_msg = q[];
	my $crcbyte;
	my $msgcrc    = 0;
	my $msgLength = length $msg;

	if ( $msg_start > 0 && $msgLength == 89 ) {
		for my $count ( 0 .. $msgLength ) {
			next if $count % 9 != 0;
			$crcbyte = substr( $msg, $count, 8 );
			if ( $count < ( length($msg) - 10 ) ) {
				$new_msg .= join q[],
				reverse @bit_msg[ $msg_start + 10 + $count .. $msg_start + 17 + $count ];
				$msgcrc = $msgcrc ^ oct("0b$crcbyte");
			}
		}
		return (1,split(//xms,$new_msg)) if ($msgcrc == oct( "0b$crcbyte" ));

		$self->_logging( q[lib/postDemo_EM, protocol - CRC ERROR], 3 );
		return 0, undef;

	}

	$self->_logging(qq[lib/postDemo_EM, protocol - Start not found or length msg ($msgLength) not correct],	3);
	return 0, undef;
}

=item postDemo_FS20()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $object,$name,@bit_msg
Output:
        (returncode = 0 on success, prepared message or undef)

=cut

sub postDemo_FS20 {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $protolength = scalar @bit_msg;
	my $datastart   = 0;
	my $sum         = 6;
	my $b           = 0;
	my $i           = 0;
	for ( $datastart = 0 ; $datastart < $protolength ; $datastart++ ) {
	    # Start bei erstem Bit mit Wert 1 suchen
		last if $bit_msg[$datastart] == 1;
	}
	if ( $datastart == $protolength ) {    # all bits are 0
		$self->_logging(qq[lib/postDemo_FS20, ERROR message all bits are zeros], 3 );
		return 0, undef;
	}
	splice( @bit_msg, 0, $datastart + 1 );    # delete preamble + 1 bit
	$protolength = scalar @bit_msg;
	$self->_logging( qq[lib/postDemo_FS20, pos=$datastart length=$protolength],	5 );
	if ( $protolength == 46 || $protolength == 55 )
	{    # If it 1 bit too long, then it will be removed (EOT-Bit)
		pop(@bit_msg);
		$protolength--;
	}
	if ( $protolength == 45 || $protolength == 54 ) {   ### FS20 length 45 or 54
		
		my $b=0;
		for ( my $b = 0 ; $b < $protolength - 9 ; $b += 9 ) 	{    
			# build sum over first 4 or 5 bytes
			$sum += oct( '0b' . ( join "", @bit_msg[ $b .. $b + 7 ] ) );
		}
		my $checksum = oct( '0b' . ( join "", @bit_msg[ $protolength - 9 .. $protolength - 2 ] ) ) ;    # Checksum Byte 5 or 6
		if ( ( ( $sum + 6 ) & 0xFF ) == $checksum )
		{      # Message from FHT80 roothermostat
			$self->_logging(qq[lib/postDemo_FS20, FS20, Detection aborted, checksum matches FHT code], 5 );
			return 0, undef;
		}
		if ( ( $sum & 0xFF ) == $checksum ) {    ## FH20 remote control
			for my $b ($b..$protolength-1) {
				next if $b % 9 != 0;	
				my $parity = 0;    # Parity even
				for my $i ($b..$b+8) { # Parity over 1 byte + 1 bit
					$parity += $bit_msg[$i];
				}
				if ( $parity % 2 != 0 ) {
					$self->_logging(qq[lib/postDemo_FS20, FS20, ERROR - Parity not even], 3 );
					return 0, undef;
				}
			}    # parity ok
			for ( my $b = $protolength - 1 ; $b > 0 ; $b -= 9 ) {    # delete 5 or 6 parity bits
				splice( @bit_msg, $b, 1 );
			}
			if ( $protolength == 45 ) {    ### FS20 length 45
				splice( @bit_msg, 32, 8 );    # delete checksum
				splice( @bit_msg, 24, 0, ( 0, 0, 0, 0, 0, 0, 0, 0 ) ); # insert Byte 3
			}
			else {                            ### FS20 length 54
				splice( @bit_msg, 40, 8 );    # delete checksum
			}
			my $dmsg = lib::SD_Protocols::binStr2hexStr( join "", @bit_msg );
			$self->_logging(qq[lib/postDemo_FS20, remote control post demodulation $dmsg length $protolength], 4 );
			return ( 1, @bit_msg );           ## FHT80TF ok
		}
		else {
			$self->_logging(qq[lib/postDemo_FS20, ERROR - wrong checksum], 4 );
		}
	}
	else {
		$self->_logging(qq[lib/postDemo_FS20, ERROR - wrong length=$protolength (must be 45 or 54)], 5 );
	}
	return 0, undef;
}

=item postDemo_FHT80()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $object,$name,@bit_msg
Output:
        (returncode = 0 on success, prepared message or undef)

=cut


sub postDemo_FHT80 {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $datastart = 0;
	my $protolength = scalar @bit_msg;
	my $sum = 12;
	my $b = 0;
	my $i = 0;
	for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
		last if $bit_msg[$datastart] == 1;
	}
	if ($datastart == $protolength) {                                 # all bits are 0
		$self->_logging(qq[lib/postDemo_FHT80, ERROR message all bit are zeros], 3 );
		return 0, undef;
   }
   splice(@bit_msg, 0, $datastart + 1);                             	# delete preamble + 1 bit
   $protolength = scalar @bit_msg;
   $self->_logging(qq[lib/postDemo_FHT80, pos=$datastart length=$protolength], 5 );
   if ($protolength == 55) {						# If it 1 bit too long, then it will be removed (EOT-Bit)
      pop(@bit_msg);
      $protolength--;
   }
   if ($protolength == 54) {                       		### FHT80 fixed length
      for($b = 0; $b < 45; $b += 9) {	                             # build sum over first 5 bytes
         $sum += oct( "0b".(join "", @bit_msg[$b .. $b + 7]));
      }
      my $checksum = oct( "0b".(join "", @bit_msg[45 .. 52]));          # Checksum Byte 6
      if ((($sum - 6) & 0xFF) == $checksum) {		## Message from FS20 remote contro
         $self->_logging(qq[lib/postDemo_FHT80, Detection aborted, checksum matches FS20 code], 5 );
         return 0, undef;
      }
      if (($sum & 0xFF) == $checksum) {								## FHT80 Raumthermostat
         for($b = 0; $b < 54; $b += 9) {	                              # check parity over 6 byte
            my $parity = 0;					                              # Parity even
			for($i = $b; $i < $b + 9; $i++) {			                  # Parity over 1 byte + 1 bit
               $parity += $bit_msg[$i];
            }
            if ($parity % 2 != 0) {
               $self->_logging(qq[lib/postDemo_FHT80, ERROR - Parity not even], 3 );
               return 0, undef;
            }
         }																					# parity ok
         for($b = 53; $b > 0; $b -= 9) {	                              # delete 6 parity bits
            splice(@bit_msg, $b, 1);
         }
         if ($bit_msg[26] != 1) {                                       # Bit 5 Byte 3 must 1
	        $self->_logging(qq[lib/postDemo_FHT80, ERROR - byte 3 bit 5 not 1], 3 );
            return 0, undef;
         }
         splice(@bit_msg, 40, 8);                                       # delete checksum
         splice(@bit_msg, 24, 0, (0,0,0,0,0,0,0,0));# insert Byte 3
         my $dmsg = lib::SD_Protocols::binStr2hexStr(join "", @bit_msg);
         $self->_logging(qq[lib/postDemo_FHT80, roomthermostat post demodulation $dmsg], 4 );
         return (1, @bit_msg);											## FHT80 ok
      }
      else {
         $self->_logging(qq[lib/postDemo_FHT80, ERROR - wrong checksum], 4 );
      }
   }
   else {
   	$self->_logging(qq[lib/postDemo_FHT80, ERROR - wrong length=$protolength (must be 54)], 5 );
   }
   return 0, undef;
}

=item postDemo_FHT80TF()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $object,$name,@bit_msg
Output:
        (returncode = 0 on success, prepared message or undef)

=cut

sub postDemo_FHT80TF {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $protolength = scalar @bit_msg;
	my $datastart = 0;
	my $sum = 12;
	my $b = 0;
	if ($protolength < 46) {                                        	# min 5 bytes + 6 bits
	   	$self->_logging(qq[lib/postDemo_FHT80TF, ERROR lenght of message < 46], 4 );
		return 0, undef;
   }
   for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
      last if $bit_msg[$datastart] == 1;
   }
   if ($datastart == $protolength) {                                 # all bits are 0
   		$self->_logging(qq[lib/postDemo_FHT80TF, ERROR message all bit are zeros], 3 );
		return 0, undef;
   }
   splice(@bit_msg, 0, $datastart + 1);                             	# delete preamble + 1 bit
   $protolength = scalar @bit_msg;
   if ($protolength == 45) {                       		      ### FHT80TF fixed length
      for(my $b = 0; $b < 36; $b += 9) {	                             # build sum over first 4 bytes
         $sum += oct( "0b".(join "", @bit_msg[$b .. $b + 7]));
      }
      my $checksum = oct( "0b".(join "", @bit_msg[36 .. 43]));          # Checksum Byte 5
      if (($sum & 0xFF) == $checksum) {									## FHT80TF Tuer-/Fensterkontakt
			for(my $b = 0; $b < 45; $b += 9) {	                           # check parity over 5 byte
				my $parity = 0;					                              # Parity even
				for(my $i = $b; $i < $b + 9; $i++) {			               # Parity over 1 byte + 1 bit
					$parity += $bit_msg[$i];
				}
				if ($parity % 2 != 0) {
				   	$self->_logging(qq[lib/postDemo_FHT80TF, ERROR Parity not even], 4 );
					return 0, undef;
				}
			}																					# parity ok
			for(my $b = 44; $b > 0; $b -= 9) {	                           # delete 5 parity bits
				splice(@bit_msg, $b, 1);
			}
         if ($bit_msg[26] != 0) {                                       # Bit 5 Byte 3 must 0
           	$self->_logging(qq[lib/postDemo_FHT80TF, ERROR - byte 3 bit 5 not 0], 3 );
            return 0, undef;
         }
         splice(@bit_msg, 32, 8);                                       # delete checksum
         my $dmsg = lib::SD_Protocols::binStr2hexStr(join "", @bit_msg);
         $self->_logging(qq[lib/postDemo_FHT80TF, door/window switch post demodulation $dmsg], 4 );
         return (1, @bit_msg);											## FHT80TF ok
      }
   }
   return 0, undef;
}

=item postDemo_WS7035()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $object,$name,@bit_msg
Output:
        (returncode = 1 on success, prepared message or undef)

=cut
sub postDemo_WS7035 {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $msg = join('',@bit_msg);
	my $parity = 0;					# Parity even
	my $sum = 0;						# checksum
    $self->_logging(qq[lib/postDemo_WS7035, $msg], 4 );
	if (substr($msg,0,8) ne '10100000') {		# check ident
	    $self->_logging(qq[lib/postDemo_WS7035, ERROR - Ident not 1010 0000],3 );
		return 0, undef;
	} else {
		for(my $i = 15; $i < 28; $i++) {			# Parity over bit 15 and 12 bit temperature
	      $parity += substr($msg, $i, 1);
		}
		if ($parity % 2 != 0) {
		    $self->_logging(qq[lib/postDemo_WS7035, ERROR - Parity not even],3 );
			return 0, undef;
		} else {
			for(my $i = 0; $i < 39; $i += 4) {			# Sum over nibble 0 - 9
				$sum += oct('0b'.substr($msg,$i,4));
			}
			if (($sum &= 0x0F) != oct('0b'.substr($msg,40,4))) {
			    $self->_logging(qq[lib/postDemo_WS7035, ERROR - wrong checksum],3 );
				return 0, undef;
			} else {
				# Todo: Regex anstelle der viele substr einf�gen
			    $self->_logging(qq[lib/postDemo_WS7035, ERROR - wrong checksum]. substr($msg,0,4) ." ". substr($msg,4,4) ." ". substr($msg,8,4) ." ". substr($msg,12,4) ." ". substr($msg,16,4) ." ". substr($msg,20,4) ." ". substr($msg,24,4) ." ". substr($msg,28,4) ." ". substr($msg,32,4) ." ". substr($msg,36,4) ." ". substr($msg,40),4 );
				substr($msg, 27, 4, '');			# delete nibble 8
				return (1,split(//,$msg));
			}
		}
	}
}

=item postDemo_WS7035()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $object,$name,@bit_msg
Output:
        (returncode = 0 on failure, prepared message or undef)

=cut

sub postDemo_WS2000 {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $protolength = scalar @bit_msg;
	my @new_bit_msg = q{};
	my @datalenghtws = (35,50,35,50,70,40,40,85);
	my $datastart = 0;
	my $datalength = 0;
	my $datalength1 = 0;
	my $index = 0;
	my $data = 0;
	my $dataindex = 0;
	my $check = 0;
	my $sum = 5;
	my $typ = 0;
	my $adr = 0;
	my @sensors = (
		'Thermo',
		'Thermo/Hygro',
		'Rain',
		'Wind',
		'Thermo/Hygro/Baro',
		'Brightness',
		'Pyrano',
		'Kombi'
		);

	for ($datastart = 0; $datastart < $protolength; $datastart++) {   # Start bei erstem Bit mit Wert 1 suchen
		last if $bit_msg[$datastart] == 1;
	}
	if ($datastart == $protolength) {                                 # all bits are 0
	    $self->_logging(qq[lib/postDemo_WS2000, ERROR message all bit are zeros],4);
		return 0, undef;
	}
	$datalength = $protolength - $datastart;
	$datalength1 = $datalength - ($datalength % 5);  		# modulo 5
    $self->_logging(qq[lib/postDemo_WS2000, protolength: $protolength, datastart: $datastart, datalength $datalength],5);
	$typ = oct( '0b'.(join "", reverse @bit_msg[$datastart + 1.. $datastart + 4]));		# Sensortyp
	if ($typ > 7) {
	    $self->_logging(qq[lib/postDemo_WS2000, Sensortyp $typ - ERROR typ to big (0-7)],5);
		return 0, undef;
	}
	if ($typ == 1 && ($datalength == 45 || $datalength == 46)) {$datalength1 += 5;}		# Typ 1 ohne Summe
	if ($datalenghtws[$typ] != $datalength1) {												# check lenght of message
	    $self->_logging(qq[lib/postDemo_WS2000, Sensortyp $typ - ERROR lenght of message $datalength1 ($datalenghtws[$typ])],4);
		return 0, undef;
	} elsif ($datastart > 10) {									# max 10 Bit preamble
	    $self->_logging(qq[lib/postDemo_WS2000, ERROR preamble > 10 ($datastart)],4);
		return 0, undef;
	} else {
		do {
			if ($bit_msg[$index + $datastart] != 1) {			# jedes 5. Bit muss 1 sein
	    		$self->_logging(qq[lib/postDemo_WS2000, Sensortyp $typ - ERROR checking bit $index],4);
				return (0, undef);
			}
			$dataindex = $index + $datastart + 1;
			$data = oct( '0b'.(join '', reverse @bit_msg[$dataindex .. $dataindex + 3]));
			if ($index == 5) {$adr = ($data & 0x07)}			# Sensoradresse
			if ($datalength == 45 || $datalength == 46) { 	# Typ 1 ohne Summe
				if ($index <= $datalength - 5) {
					$check = $check ^ $data;		# Check - Typ XOR Adresse XOR  bis XOR Check muss 0 ergeben
				}
			} else {
				if ($index <= $datalength - 10) {
					$check = $check ^ $data;		# Check - Typ XOR Adresse XOR  bis XOR Check muss 0 ergeben
					$sum += $data;
				}
			}
			$index += 5;
		} until ($index >= $datalength -1 );
	}
	if ($check != 0) {
   		$self->_logging(qq[lib/postDemo_WS2000, Sensortyp $typ Adr $adr - ERROR check XOR],4);
		return (0, undef);
	} else {
		if ($datalength < 45 || $datalength > 46) { 			# Summe pruefen, au�er Typ 1 ohne Summe
			$data = oct( "0b".(join '', reverse @bit_msg[$dataindex .. $dataindex + 3]));
			if ($data != ($sum & 0x0F)) {
   				$self->_logging(qq[lib/postDemo_WS2000, Sensortyp $typ Adr $adr - ERROR sum],4);
				return (0, undef);
			}
		}
		$self->_logging(qq[lib/postDemo_WS2000, Sensortyp $typ Adr $adr - $sensors[$typ]],4);
		$datastart += 1;																							# [x] - 14_CUL_WS
		@new_bit_msg[4 .. 7] = reverse @bit_msg[$datastart .. $datastart+3];							# [2]  Sensortyp
		@new_bit_msg[0 .. 3] = reverse @bit_msg[$datastart+5 .. $datastart+8];						# [1]  Sensoradresse
		@new_bit_msg[12 .. 15] = reverse @bit_msg[$datastart+10 .. $datastart+13];				# [4]  T 0.1, R LSN, Wi 0.1, B   1, Py   1
		@new_bit_msg[8 .. 11] = reverse @bit_msg[$datastart+15 .. $datastart+18];					# [3]  T   1, R MID, Wi   1, B  10, Py  10
		if ($typ == 0 || $typ == 2) {		# Thermo (AS3), Rain (S2000R, WS7000-16)
			@new_bit_msg[16 .. 19] = reverse @bit_msg[$datastart+20 .. $datastart+23];			# [5]  T  10, R MSN
		} else {
			@new_bit_msg[20 .. 23] = reverse @bit_msg[$datastart+20 .. $datastart+23];			# [6]  T  10, 			Wi  10, B 100, Py 100
			@new_bit_msg[16 .. 19] = reverse @bit_msg[$datastart+25 .. $datastart+28];			# [5]  H 0.1, 			Wr   1, B Fak, Py Fak
			if ($typ == 1 || $typ == 3 || $typ == 4 || $typ == 7) {	# Thermo/Hygro, Wind, Thermo/Hygro/Baro, Kombi
				@new_bit_msg[28 .. 31] = reverse @bit_msg[$datastart+30 .. $datastart+33];		# [8]  H   1,			Wr  10
				@new_bit_msg[24 .. 27] = reverse @bit_msg[$datastart+35 .. $datastart+38];		# [7]  H  10,			Wr 100
				if ($typ == 4) {	# Thermo/Hygro/Baro (S2001I, S2001ID)
					@new_bit_msg[36 .. 39] = reverse @bit_msg[$datastart+40 .. $datastart+43];	# [10] P    1
					@new_bit_msg[32 .. 35] = reverse @bit_msg[$datastart+45 .. $datastart+48];	# [9]  P   10
					@new_bit_msg[44 .. 47] = reverse @bit_msg[$datastart+50 .. $datastart+53];	# [12] P  100
					@new_bit_msg[40 .. 43] = reverse @bit_msg[$datastart+55 .. $datastart+58];	# [11] P Null
				}
			}
		}
		return (1, @new_bit_msg);
	}
}



=item postDemo_WS7053()
This sub checks the bit sequence. On an error in the CRC or no start, it issues an output.

Input:  $object,$name,@bit_msg
Output:
        (returncode = 0 on failure, prepared message or undef)

=cut

sub postDemo_WS7053 {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $msg = join("",@bit_msg);
	my $parity = 0;	                       # Parity even
	$self->_logging(qq[lib/postDemo_WS7053, MSG = $msg],4);
	my $msg_start = index($msg, '10100000');
	if ($msg_start > 0) {                  # start not correct
		$msg = substr($msg, $msg_start);
		$msg .= '0';
		$self->_logging(qq[lib/postDemo_WS7053, cut $msg_start char(s) at begin],5);
	}
	if ($msg_start < 0) {                  # start not found
		$self->_logging(qq[lib/postDemo_WS7053, ERROR - Ident 10100000 not found],3);
		return 0, undef;
	} else {
		if (length($msg) < 32) {             # msg too short
			$self->_logging(qq[lib/postDemo_WS7053, ERROR - msg too short, length ] . length($msg),3);
		return 0, undef;
		} else {
			for(my $i = 15; $i < 28; $i++) {   # Parity over bit 15 and 12 bit temperature
				$parity += substr($msg, $i, 1);
			}
			if ($parity % 2 != 0) {
				$self->_logging(qq[lib/postDemo_WS7053, ERROR - Parity not even] . length($msg),3);
				return 0, undef;
			} else {
				# Todo substr durch regex ersetzen
				$self->_logging(qq[lib/postDemo_WS7053, before: ] . substr($msg,0,4) ." ". substr($msg,4,4) ." ". substr($msg,8,4) ." ". substr($msg,12,4) ." ". substr($msg,16,4) ." ". substr($msg,20,4) ." ". substr($msg,24,4) ." ". substr($msg,28,4),5);
				# Format from 7053:  Bit 0-7 Ident, Bit 8-15 Rolling Code/Parity, Bit 16-27 Temperature (12.3), Bit 28-31 Zero
				my $new_msg = substr($msg,0,28) . substr($msg,16,8) . substr($msg,28,4);
				# Format for CUL_TX: Bit 0-7 Ident, Bit 8-15 Rolling Code/Parity, Bit 16-27 Temperature (12.3), Bit 28 - 35 Temperature (12), Bit 36-39 Zero
				$self->_logging(qq[lib/postDemo_WS7053, after: ] .  substr($new_msg,0,4) ." ". substr($new_msg,4,4) ." ". substr($new_msg,8,4) ." ". substr($new_msg,12,4) ." ". substr($new_msg,16,4) ." ". substr($new_msg,20,4) ." ". substr($new_msg,24,4) ." ". substr($new_msg,28,4) ." ". substr($new_msg,32,4) ." ". substr($new_msg,36,4),5);
				return (1,split("",$new_msg));
			}
		}
	}
}


=item postDemo_lengtnPrefix()
calculates the hex (in bits) and adds it at the beginning of the message

Input:  $object,$name,@bit_msg
Output:
        (returncode = 0 on failure, prepared message or undef)

=cut

sub postDemo_lengtnPrefix {
	my $self 		= shift // carp 'Not called within an object';
	my $name 		= shift // carp 'no $name provided';
	my @bit_msg  	= @_;

	my $msg = join('',@bit_msg);
	$msg=sprintf('%08b', length($msg)).$msg;

	return (1,split('',$msg));
}





############################################################

=item PreparingSend_FS20_FHT()
This sub prepares the send message.

Input:  $id,$sum,$msg
Output:
        prepares message

=cut

sub PreparingSend_FS20_FHT {
	my $self = shift // carp 'Not called within an object';
	my $id   = shift // carp 'no idprovided';
	my $sum  = shift // carp 'no sum provided';
	my $msg  = shift // carp 'no msg provided';

	return if ( $id > 74 || $id < 73 );

	my $temp      = 0;
	my $newmsg    = q[P] . $id . q[#0000000000001];    # 12 Bit Praeambel, 1 bit
	my $msgLength = length $msg;

	for my $i ( 0 .. $msgLength - 1 ) {
		next if $i % 2 != 0;
		$temp = hex( substr( $msg, $i, 2 ) );
		$sum += $temp;
		$newmsg .= dec2binppari($temp);
	}

	$newmsg .= dec2binppari( $sum & 0xFF );            # Checksum
	my $repeats = $id - 71;                            # FS20(74)=3, FHT(73)=2
	return $newmsg . q[0P#R] . $repeats;               # EOT, Pause, 3 Repeats
}

############################################################
# xFSK method functions
############################################################

=item ConvPCA301()
This sub checks crc and converts data to a format which the PCA301 module can handle
croaks if called with less than one parameters

Input:  $hexData
Output:
        scalar converted message on success 
		or array (1,"Error message")

=cut

sub ConvPCA301 {
	my $self    = shift // carp 'Not called within an object';
	my $hexData = shift // croak 'Error: called without $hexdata as input';

	return ( 1,
'ConvPCA301, Usage: Input #1, $hexData needs to be at least 24 chars long'
	) if ( length($hexData) < 24 );    # check double, in def length_min set

	my $checksum = substr( $hexData, 20, 4 );
	my $ctx = Digest::CRC->new(
		width  => 16,
		poly   => 0x8005,
		init   => 0x0000,
		refin  => 0,
		refout => 0,
		xorout => 0x0000
	);
	my $calcCrc = sprintf( "%04X",
		$ctx->add( pack 'H*', substr( $hexData, 0, 20 ) )->digest );

	return ( 1, qq[ConvPCA301, checksumCalc:$calcCrc != checksum:$checksum] )
	  if ( $calcCrc ne $checksum );

	my $channel = hex( substr( $hexData, 0, 2 ) );
	my $command = hex( substr( $hexData, 2, 2 ) );
	my $addr1   = hex( substr( $hexData, 4, 2 ) );
	my $addr2   = hex( substr( $hexData, 6, 2 ) );
	my $addr3   = hex( substr( $hexData, 8, 2 ) );
	my $plugstate = substr( $hexData, 11, 1 );
	my $power1       = hex( substr( $hexData, 12, 2 ) );
	my $power2       = hex( substr( $hexData, 14, 2 ) );
	my $consumption1 = hex( substr( $hexData, 16, 2 ) );
	my $consumption2 = hex( substr( $hexData, 18, 2 ) );

	return ("OK 24 $channel $command $addr1 $addr2 $addr3 $plugstate $power1 $power2 $consumption1 $consumption2 $checksum"	);
}

############################################################

=item ConvKoppFreeControl()
This sub checks crc and converts data to a format which the KoppFreeControl module can handle
croaks if called with less than one parameters

Input:  $hexData
Output:
        scalar converted message on success 
		or array (1,"Error message")

=cut

sub ConvKoppFreeControl {
	my $self    = shift // carp 'Not called within an object';
	my $hexData = shift // croak 'Error: called without $hexdata as input';

	return ( 1,
'ConvKoppFreeControl, Usage: Input #1, $hexData needs to be at least 4 chars long'
	) if ( length($hexData) < 4 );    # check double, in def length_min set

	my $anz = hex( substr( $hexData, 0, 2 ) ) + 1;
	my $blkck = 0xAA;

	for my $i ( 0 .. $anz - 1 ) {
		my $d = hex( substr( $hexData, $i * 2, 2 ) );
		$blkck ^= $d;
	}
	return ( 1, 'ConvKoppFreeControl, hexData is to short' )
	  if ( length($hexData) < $anz * 2 );  # check double, in def length_min set

	my $checksum = hex( substr( $hexData, $anz * 2, 2 ) );

	return ( 1,
		qq[ConvKoppFreeControl, checksumCalc:$blkck != checksum:$checksum] )
	  if ( $blkck != $checksum );
	return ( "kr" . substr( $hexData, 0, $anz * 2 ) );
}

############################################################

=item ConvLaCrosse()
This sub checks crc and converts data to a format which the LaCrosse module can handle
croaks if called with less than one parameter

Input:  $hexData
Output:
        scalar converted message on success 
		or array (1,"Error message")

Message Format:
	
	 .- [0] -. .- [1] -. .- [2] -. .- [3] -. .- [4] -.
	 |       | |       | |       | |       | |       |
	 SSSS.DDDD DDN_.TTTT TTTT.TTTT WHHH.HHHH CCCC.CCCC
	 |  | |     ||  |  | |  | |  | ||      | |       |
	 |  | |     ||  |  | |  | |  | ||      | `--------- CRC
	 |  | |     ||  |  | |  | |  | |`-------- Humidity
	 |  | |     ||  |  | |  | |  | |
	 |  | |     ||  |  | |  | |  | `---- weak battery
	 |  | |     ||  |  | |  | |  |
	 |  | |     ||  |  | |  | `----- Temperature T * 0.1
	 |  | |     ||  |  | |  |
	 |  | |     ||  |  | `---------- Temperature T * 1
	 |  | |     ||  |  |
	 |  | |     ||  `--------------- Temperature T * 10
	 |  | |     | `--- new battery
	 |  | `---------- ID
	 `---- START

=cut

sub ConvLaCrosse {
	my $self    = shift // carp 'Not called within an object';
	my $hexData = shift // croak 'Error: called without $hexdata as input';

	return ( 1,
'ConvLaCrosse, Usage: Input #1, $hexData needs to be at least 8 chars long'
	  )
	  if ( length($hexData) < 8 )
	  ;    # check number of length for this sub to not throw an error

	my $ctx = Digest::CRC->new( width => 8, poly => 0x31 );
	my $calcCrc = $ctx->add( pack 'H*', substr( $hexData, 0, 8 ) )->digest;
	my $checksum = sprintf( "%d", hex( substr( $hexData, 8, 2 ) ) );
	return ( 1, qq[ConvLaCrosse, checksumCalc:$calcCrc != checksum:$checksum] )
	  if ( $calcCrc != $checksum );

	my $addr =
	  ( ( hex( substr( $hexData, 0, 2 ) ) & 0x0F ) << 2 ) |
	  ( ( hex( substr( $hexData, 2, 2 ) ) & 0xC0 ) >> 6 );
	my $temperature = (
		(
			( ( hex( substr( $hexData, 2, 2 ) ) & 0x0F ) * 100 ) +
			  ( ( ( hex( substr( $hexData, 4, 2 ) ) & 0xF0 ) >> 4 ) * 10 ) +
			  ( hex( substr( $hexData, 4, 2 ) ) & 0x0F )
		) / 10
	) - 40;
	return ( 1, qq[ConvLaCrosse, temp:$temperature (out of Range)] )
	  if ( $temperature >= 60 || $temperature <= -40 )
	  ;    # Shoud be checked in logical module

	my $humidity = hex( substr( $hexData, 6, 2 ) );
	my $batInserted = ( hex( substr( $hexData, 2, 2 ) ) & 0x20 ) << 2;
	my $SensorType = 1;

	my $humObat = $humidity & 0x7F;

	if ( $humObat == 125 ) {    # Channel 2
		$SensorType = 2;
	}
	elsif ( $humObat > 99 ) {    # Shoud be checked in logical module
		return ( -1, qq[ConvLaCrosse: hum:$humObat (out of Range)] );
	}

	# build string for 36_LaCrosse.pm
	$temperature = ( ( $temperature * 10 + 1000 ) & 0xFFFF );
	my $t1          = ( $temperature >> 8 ) & 0xFF;
	my $t2          = $temperature & 0xFF;
	my $sensTypeBat = $SensorType | $batInserted;
	return (qq[OK 9 $addr $sensTypeBat $t1 $t2 $humidity]);
}

1;
