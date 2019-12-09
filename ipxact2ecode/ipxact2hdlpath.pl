#!/usr/local/bin/perl -w

##################################################################################################
# Developer: Yehuda Tsimanis
# Motivation: auto-generate hdl_path() bindings for DV environments
# Description: Builds NoC SCBD configuration file from IP-XACT 2009.
# Example: ipxact2hdlpath.pl -xml <ipxact.xml>
# Verification (see TB script commented out in the bottom of the file):
#     * verify all the flags
#
# ISSUES:
#     1. Address map is missing from the current Sonics IP-XACT, we parse. It appears in a different 
#        file, which isn't clear how to integrate with the one we work in. Sonics need to explain the 
#        structure.
#     2. Start-end addresses generated from the NoC IP-XACT are absolute, as the reference point isn't 
#        the block, but the whole NoC.
#     3. AHB UVC hasn't been developed yet, therefore in Neptune, the script output for MIPS CPU 
#        (EB2AHB) cannot be used. In the design, the endpoint is OCP I/F.
#        For the proof of concept in Neptune, we copied the MIPS agent agent configuration from the 
#        original file, manually coded by DotanB.
#     4. Agent names fetched from IP-XACT itself will be mapped to UVC names in the TB, this mapping 
#        will be one of the input files for the script.
#     5. Some UVC have manual configuration that IP-XACT isn't aware of. Example: OCP flavours.
#     7. FIXME: Update the compare_and_update method by removing the registers base_addr: 
#        /vobs/neptune/dv/evc/neptune_all_rcgs/no_phy/e/neptune_all_rcgs_env.e
#     8. FIXME: Remove address conversions /vobs/neptune/dv/soc/e/neptune_matrix_scbd_cfg.e
##################################################################################################

use strict;
use warnings;
use Getopt::Long;
require XML::LibXML;
use File::Basename;

my $SCRIPTNAME = basename($0);
my $logfile=$SCRIPTNAME;
$logfile=~s/.pl$/.log/;
open(LOG,">", $logfile) or die "Error: Cannot create log file '$logfile'.\n";

&syntax() if @ARGV==0;
my $cmd = "Command: ".join(" ", @ARGV)."\n";
&log($cmd);

#busType can be APBML, AHBML, AXI4
#the order of pins is in the order as it appears in the standards
my %evc_to_protocol_signal_mapping;
my %apbmapping = (
    'UVC_PREFIX' => 'crgn_apb_uvc'
    ,'DATA_WIDTH' => 'PWDATA'
    ,'PCLK'       => 'port_clock'
    ,'PRESETn'    => 'port_reset'
    ,'PADDR'      => 'apb_addr_p'
    ,'PSELx'      => 'apb_sel_p'
    ,'PENABLE'    => 'apb_enable_p'
    ,'PWRITE'     => 'apb_write_p'
    ,'PWDATA'     => 'apb_wdata_p'
    ,'PSTRB'      => 'apb_wstrb_p'
    ,'PREADY'     => 'apb_ready_p'
    ,'PRDATA'     => 'apb_rdata_p'
    ,'PSLVERR'    => 'apb_slverr_p'
);
$evc_to_protocol_signal_mapping{'APBML'} = \%apbmapping;

my %ahbmapping = (
    'UVC_PREFIX' => 'crgn_ahb_uvc'
    ,'DATA_WIDTH' => 'HWDATA'
    ,'HCLK'       => 'port_clock'
    ,'HRESETn'    => 'port_reset'
    ,'HADDR'      => 'ahb_addr_p'
    ,'HBURST'     => 'ahb_burst_p'
    #,'HMASTLOCK'  => 'NA'
    ,'HPROT'      => 'ahb_prot_p'
    ,'HSIZE'      => 'ahb_size_p'
    ,'HTRANS'     => 'ahb_trans_p'
    ,'HWDATA'     => 'ahb_wdata_p'
    ,'HWRITE'     => 'ahb_write_p'
    ,'HRDATA'     => 'ahb_rdata_p'
    ,'HREADY'     => 'ahb_ready_p'
    ,'HRESP'      => 'ahb_resp_p'
    #,'HSELx'      => 'NA'
);
$evc_to_protocol_signal_mapping{'AHBML'} = \%ahbmapping;

my %aximapping = (
    'UVC_PREFIX' => 'crgn_axi_uvc'
    ,'DATA_WIDTH' => 'WDATA'
    ,'ACLK'       => 'port_clock'
    ,'ARESETn'    => 'port_reset'

    ,'AWID'       => 'axi_awid_p'
    ,'AWADDR'     => 'axi_awaddr_p'
    ,'AWLEN'      => 'axi_awlen_p'
    ,'AWSIZE'     => 'axi_awsize_p'
    ,'AWBURST'    => 'axi_awburst_p'
    #,'AWLOCK'     => 'NA'
    #,'AWCACHE'    => 'NA'
    #,'AWPROT'     => 'NA'
    ,'AWVALID'    => 'axi_awvalid_p'
    ,'AWREADY'    => 'axi_awready_p'

    ,'WID'        => 'axi_wid_p'
    ,'WDATA'      => 'axi_wdata_p'
    ,'WSTRB'      => 'axi_wstrb_p'
    ,'WLAST'      => 'axi_wlast_p'
    ,'WVALID'     => 'axi_wvalid_p'
    ,'WREADY'     => 'axi_wready_p'

    ,'BID'        => 'axi_bid_p'
    ,'BRESP'      => 'axi_bresp_p'
    ,'BVALID'     => 'axi_bvalid_p'
    ,'BREADY'     => 'axi_bready_p'

    ,'ARID'       => 'axi_arid_p'
    ,'ARADDR'     => 'axi_araddr_p'
    ,'ARLEN'      => 'axi_arlen_p'
    ,'ARSIZE'     => 'axi_arsize_p'
    ,'ARBURST'    => 'axi_arburst_p'
    #,'ARLOCK'     => 'NA'
    #,'ARCACHE'    => 'NA'
    #,'ARPROT'     => 'NA'
    ,'ARVALID'    => 'axi_arvalid_p'
    ,'ARREADY'    => 'axi_arready_p'

    ,'RID'        => 'axi_rid_p'
    ,'RDATA'      => 'axi_rdata_p'
    ,'RRESP'      => 'axi_rresp_p'
    ,'RLAST'      => 'axi_rlast_p'
    ,'RVALID'     => 'axi_rvalid_p'
    ,'RREADY'     => 'axi_rready_p'
);
$evc_to_protocol_signal_mapping{'AXI4'} = \%aximapping;

my %ocpmapping = (
    'UVC_PREFIX'      => 'crgn_ocp_uvc'
    ,'DATA_WIDTH'      => 'MData'
    ,'Clk'             => 'port_clock'
    ,'MReset_n'        => 'port_reset'
    ,'SReset_n'        => 'port_reset'

    #,'EnableClk'       => 'NA'
    ,'MAddr'           => 'sig_mAddr'
    ,'MCmd'            => 'sig_mCmd'
    ,'MData'           => 'sig_mData'
    ,'MDataValid'      => 'sig_mDataValid'
    ,'MRespAccept'     => 'sig_mRespAccept'
    ,'SCmdAccept'      => 'sig_sCmdAccept'
    ,'SData'           => 'sig_sData'
    ,'SDataAccept'     => 'sig_sDataAccept'
    ,'SResp'           => 'sig_sResp'

    #,'MAddrSpace'      => 'NA'
    ,'MByteEn'         => 'sig_mByteEn'
    ,'MDataByteEn'     => 'sig_mDataByteEn'
    #,'MDataInfo'       => 'NA'
    #,'MReqInfo'        => 'NA'
    #,'SDataInfo'       => 'NA'
    #,'SRespInfo'       => 'NA'

    #,'MAtomicLength'   => 'NA'
    #,'MBlockHeight'    => 'NA'
    #,'MBlockStride'    => 'NA'
    ,'MBurstLength'    => 'sig_mBurstLength'
    ,'MBurstPrecise'   => 'sig_mBurstPrecise'
    ,'MBurstSeq'       => 'sig_mBurstSeq'
    ,'MBurstSingleReq' => 'sig_mBurstSingleReq'
    ,'MDataLast'       => 'sig_mDataLast'
    #,'MDataRowLast'    => 'NA'
    ,'MReqLast'        => 'sig_mReqLast'
    #,'MReqRowLast'     => 'NA'
    ,'SRespLast'       => 'sig_sRespLast'
    #,'SRespRowLast'    => 'NA'

    ,'MDataTagID'      => 'sig_mDataTagID'
    ,'MTagID'          => 'sig_mTagID'
    ,'MTagInOrder'     => 'sig_mTagInOrder'
    ,'STagID'          => 'sig_sTagID'
    ,'STagInOrder'     => 'sig_sTagInOrder'

    #,'MConnID'         => 'NA'
    #,'MDataThreadID'   => 'NA'
    #,'MThreadBusy'     => 'NA'
    #,'MThreadID'       => 'NA'
    #,'SDataThreadBusy' => 'NA'
    #,'SThreadBusy'     => 'NA'
    #,'SThreadID'       => 'NA'

    #,'MConnect'        => 'NA'
    #,'MError'          => 'NA'
    #,'MFlag'           => 'NA'
    #,'SConnect'        => 'NA'
    #,'SError'          => 'NA'
    #,'SFlag'           => 'NA'
    #,'SInterrupt'      => 'NA'
    #,'SWait'           => 'NA'
    #,'ConnectCap'      => 'NA'
    #,'Control'         => 'NA'
    #,'ControlBusy'     => 'NA'
    #,'ControlWr'       => 'NA'
    #,'Status'          => 'NA'
    #,'StatusBusy'      => 'NA'
    #,'StatusRd'        => 'NA'
);
$evc_to_protocol_signal_mapping{'OCP2_2'} = \%ocpmapping;

&log("Running IP-XACT parser: $SCRIPTNAME \n");

my ($xmlfile,
    #$componentPath,
    $userConfigurations,
    $manuallyBinded,
    $debug);

GetOptions (
    'xml=s'       => \$xmlfile,
    #'cp=s'        => \$componentPath,
    'ucfg'        => \$userConfigurations,
    'mb=s'        => \$manuallyBinded,
    'debug'       => \$debug,
    'help'        => \&syntax
);

if ($Getopt::Long::error) {
    print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n");
    print("||||||||||||||||||||||||||||||||\n\n");
    print(" run with -help for user manual\n\n");
    print("||||||||||||||||||||||||||||||||\n\n");
    #&syntax();
    exit;
};

sub syntax {
    print <<EOF;
=================================================================================================================================================  
The script builds NoC SCBD configuration file from IP-XACT 2009.                                                                                 
The script converts IP-XACT XML data into:                                                                                                       
    - UVC creates subtypes for each agend                                                                                                        
    - configurates UVCs with data that can be fetched from IP-XACT                                                                               
    - hdl_path() simple ports bindings                                                                                                           
=================================================================================================================================================  
Arguments:                                                                                                                                       
    -xml <xml_file> : String argument: IP-XACTS input file (in XML format, by definition).                                                                                           
    -debug          : Boolean flag:    Adds higher verbosity & creates a 'test.e' for newly created sub-types testing. Read 'test.e' 
                                       for more info.                              
    -ucfg           : Boolean flag:    Creates a file of empty Specman extensions to the subtypes extended by the script. These extensions
                                       should be filled with manually coded constrains that cannot be fetched from IP-XACT. While the main output
                                       file has definitions of new subtype & IP-XACT based extensions, this file gives user an option to add to 
                                       it without editing the main output file.
    -mb <csv_file>  : String argument: Linux fullpath to the file of signals that should be manually binded to certain UVC ports, overriding IP-XACT connections. 
    -help           : Boolean flag   : Prints this message and exits.                                                                                             
=================================================================================================================================================  
Usage examples:                                                                                                                                   
    command line:
        $SCRIPTNAME -xml /vobs/neptune/dv/scripts/ipxact_example.xml -debug

    ucfg file format:
        Main output:
            // busInterface: mmspi0_axi (library:AMBA4 name:AXI4 version:r0p0_0)
            // busType     : library=AMBA4 name=AXI4 version=r0p0_0
            extend crgn_busp_uvc_env_name_t: [MMSPI0_AXI_S];
            extend MMSPI0_AXI_S crgn_axi_uvc_env_u {
                keep      kind                 == SLAVE;
                keep      cfg.data_bus_width   == DATA_BUS_WIDTH_32BIT;
                keep soft agent.active_passive == PASSIVE;
            };
        User defined (ucfg) will look like:
            // busInterface: mmspi0_axi (library:AMBA4 name:AXI4 version:r0p0_0)
            // busType     : library=AMBA4 name=AXI4 version=r0p0_0
            extend MMSPI0_AXI_S crgn_axi_uvc_env_u {
            };

    mb (manually binded) file format (w/ legend):
        <evc_name:simple_port_name:hdl_path>
        evcname_0:evcsp_a:hdl_path_I
        evcname_1:evcsp_b:hdl_path_II
        evcname_2:evcsp_c:hdl_path_III
        evcname_3:evcsp_d:hdl_path_IV
        ...
        evcname_k:evcsp_z:hdl_path_M
=================================================================================================================================================  
EOF
    exit;
    #The Line is removed from the help discription
    #   -nhp            : hdl_path to NoC
}

## Argument defaults:
$userConfigurations = 0  unless defined $userConfigurations;
$debug              = 0  unless defined $debug;

# Output file handlers
my ($autocfgs, $usercfgs);

# Some statistics counters
my ($stsnumbusifs, $numportmaps, $stsmbcnt) = (0,0,0);
my @busifsfortest;

my %manuallyBinded_h;
if (defined $manuallyBinded) {
    #FIXME: Currently we kill the script if this option is used. The 'die' will be removed, when the feature is supported
    die ("Manually binded signals aren't supported yet. Remove -mb from your command line !!!\n");

    # If it's a file and is not empty
    if (-f $manuallyBinded && -s $manuallyBinded) {
        $stsmbcnt = &read_mb_file( $manuallyBinded );
    } else {
        die "Error: $manuallyBinded is not a file"    if -f $manuallyBinded;
        die "Error: $manuallyBinded is an empty file" if -s $manuallyBinded;
    };
};

## Parse XML file:
die "Error: Please specify an IP-XACT XML file name!\n" unless defined $xmlfile;
die "Error: IP-XACT XML file '$xmlfile' does not exist!\n" unless -r $xmlfile;
#my $parser = XML::LibXML->new();
#my $ipxml = $parser->parse_file($xmlfile);
my $dom = XML::LibXML->load_xml(location => $xmlfile);
&log("File $xmlfile is parsed successfully\n");

my $xmlfilename      = basename($xmlfile);
my $autocfgsfilename = $xmlfilename;
$autocfgsfilename    =~ s/\.xml$/_uvc_autocfgs.e/i;
my $usercfgsfilename = $xmlfilename;
$usercfgsfilename    =~ s/\.xml$/_uvc_usercfgs.e/i;

###################################################################################################################
# Running MAIN
###################################################################################################################
open($autocfgs, '>', $autocfgsfilename) or die "Error: Cannot create $autocfgsfilename\n";
open($usercfgs, '>', $usercfgsfilename) or die "Error: Cannot create $usercfgsfilename\n" if $userConfigurations;

&main();

close $autocfgs or die "Error: cannot close $autocfgs";
close $usercfgs or die "Error: cannot close $usercfgs" if $userConfigurations;

&log("\nStatistics:\n");
&log("\teVCs (spirit:busInterface)        :\t$stsnumbusifs\n");
&log("\tconnected ports (spirit:portMaps) :\t$numportmaps\n");
&log("\tmanually binded ports             :\t$stsmbcnt\n");
print "\n";

&dump_test() if $debug;

exit;
###################################################################################################################

sub main {
    foreach my $component ($dom->findnodes('//spirit:component')) {
        my $cname = $component->findvalue('./spirit:name');
        &log("component name = $cname\n") if $debug;
        print $autocfgs "// Automatically generated from $xmlfile\n";
        print $autocfgs "// Component = $cname\n";
        print $autocfgs "<'\n\n";
        if ($userConfigurations) {
            print $usercfgs "// Configuration file to be manually filled in\n";
            print $usercfgs "// The extensions below are based on subtypes automatically generated from $xmlfile\n\n";
            print $usercfgs "<'\n\n";
        };

        BUSIFS : foreach my $busInteface ($component->findnodes('./spirit:busInterfaces/spirit:busInterface')) {
            my %boundsps;
            my $busifname     = $busInteface->findvalue('./spirit:name');
            my @busifismaster = $busInteface->findnodes('./spirit:master');
            my @busifisslave  = $busInteface->findnodes('./spirit:slave');
            my @busifissystem = $busInteface->findnodes('./spirit:system');
            my @busType       = $busInteface->findnodes('./spirit:busType');

            next BUSIFS if @busifissystem;
            unless (scalar(@busType) == 1) {
                die "Error: IP-XACT Standard defines one busType element for each busInterface. $busifname has ".scalar(@busType)." !";
            };
            $stsnumbusifs++;
            #TODO: we may want to change usage of getAttribute to @ operator. Example: $busType[0]->getAttribute('spirit:name') <===> $busInteface->findnodes('./spirit:busType/@name')
            my $bustypelibrary = $busType[0]->getAttribute('spirit:library');
            my $bustypename    = $busType[0]->getAttribute('spirit:name');
            my $bustypeversion = $busType[0]->getAttribute('spirit:version');

            unless ( ($bustypename eq 'APBML') or 
                ($bustypename eq 'AHBML') or 
                ($bustypename eq 'AXI4')  or 
                ($bustypename eq 'OCP2_2') ) {
                warn "Warning: ' $bustypename ' is unsupported bus protocol. Please, provide protocol vs UVC mapping\n";
                next;
            };
            my $databusport  = $evc_to_protocol_signal_mapping{$bustypename}{'DATA_WIDTH'};
            die "Error: DATA_WIDTH isn't mapped to the congruent bus protocol port\n" unless ($databusport);
            #TODO: this data should be obtained from IP-XACT
            #TODO: at least write_data width should be compared to read_data_width to make sure it's the same, otherwise it violates the env assumption
            my $databuswidth; # IP-XACT contains left and right boundaries. Example: left=31, right=0. width=left-right+1=31-0+1=32
            BUS_WIDTH_SEARCHER : foreach my $portMap ($busInteface->findnodes('./spirit:portMaps/spirit:portMap')) {
                my $logicalportname = $portMap->findvalue('./spirit:logicalPort/spirit:name');
                next BUS_WIDTH_SEARCHER unless ($logicalportname eq $databusport);
                my $logicalPortVectorLeft  = $portMap->findvalue('./spirit:logicalPort/spirit:vector/spirit:left');
                my $logicalPortVectorRight = $portMap->findvalue('./spirit:logicalPort/spirit:vector/spirit:right');
                die "Error: logicalPortVectorLeft  hasn't been found in $logicalportname of $busifname" if (not defined $logicalPortVectorLeft );
                die "Error: logicalPortVectorRight hasn't been found in $logicalportname of $busifname" if (not defined $logicalPortVectorRight);
                $databuswidth =  $logicalPortVectorLeft - $logicalPortVectorRight + 1;
            };
            my $ucbusifname  = uc($busifname);
            $ucbusifname  = uc($busifname)."_M" if @busifisslave;
            $ucbusifname  = uc($busifname)."_S" if @busifismaster;
            my $uvcprefixname  = $evc_to_protocol_signal_mapping{$bustypename}{'UVC_PREFIX'};
            my $uvcenvname   = $uvcprefixname."_env_u";
            my $uvcportsname = $uvcprefixname."_ports_u";
            push @busifsfortest, "$busifname:$ucbusifname:$uvcenvname" if $debug;

            my $path = "$cname/$busifname($bustypename)";
            &log("busInterface = $path\n") if $debug;
            print $autocfgs "// busInterface: $busifname (library:$bustypelibrary name:$bustypename version:$bustypeversion)\n";
            print $autocfgs "// busType     : library=$bustypelibrary name=$bustypename version=$bustypeversion\n";
            print $autocfgs "extend crgn_busp_uvc_env_name_t: [".$ucbusifname."];\n";
            print $autocfgs "extend $ucbusifname $uvcenvname {\n";
            print $autocfgs "    keep      kind                 == MASTER;\n" if (@busifisslave); # If a NOC port is a slave,  then UVC is a MASTER
            print $autocfgs "    keep      kind                 == SLAVE;\n"  if @busifismaster;  # If a NOC port is a master, then UVC is a SLAVE
            #        print $autocfgs "    keep      hdl_path()           == \"$componentPath\";\n";
            print $autocfgs "    keep      cfg.data_bus_width   == DATA_BUS_WIDTH_".$databuswidth."BIT;\n";
            print $autocfgs "    keep soft agent.active_passive == PASSIVE;\n";
            print $autocfgs "};\n\n";

            if ($userConfigurations) {
                print $usercfgs "// busInterface: $busifname (library:$bustypelibrary name:$bustypename version:$bustypeversion)\n";
                print $usercfgs "// busType     : library=$bustypelibrary name=$bustypename version=$bustypeversion\n";
                print $usercfgs "extend $ucbusifname $uvcenvname {\n";
                print $usercfgs "};\n\n";
            };

            print $autocfgs "extend $ucbusifname DATA_BUS_WIDTH_${databuswidth}BIT $uvcportsname {\n";
            PORTMAPS : foreach my $portMap ($busInteface->findnodes('./spirit:portMaps/spirit:portMap')) {
                $numportmaps++;
                my $logicalportname  = $portMap->findvalue('./spirit:logicalPort/spirit:name');
                my $physicalportname = $portMap->findvalue('./spirit:physicalPort/spirit:name');
                $path = "$cname/$busifname($bustypename)/$logicalportname";
                &log("portMap = $path\n") if $debug;
                my $evcportname = $evc_to_protocol_signal_mapping{$bustypename}{$logicalportname};
                unless ($evcportname) {
                    warn "Warning: Port $logicalportname isn't mapped to the congruent eVC port\n";
                } else {
                    die  "Error: Port $logicalportname is mapped to NA, a non-existing UVC field" if ($evcportname eq 'NA');
                    print $autocfgs "    // logicalPort = $logicalportname\n";
                    print $autocfgs "    keep $evcportname.hdl_path()==\"$physicalportname\";\n";
                    print $autocfgs "    keep soft bind($evcportname, external);\n";
                    $boundsps{$evcportname}++;
                };
            };
            # checking that no port was bound more then once
            foreach my $spname (keys %boundsps) {
                my $numofbounds = $boundsps{$spname};
                die "Error: the port $spname was bound $numofbounds times" if ($boundsps{$spname} > 1);
            };
            print $autocfgs "\n";

            SCAN_MAPPED: foreach my $lpname ( keys %{ $evc_to_protocol_signal_mapping{$bustypename} } ) {
                my $epname = $evc_to_protocol_signal_mapping{$bustypename}{$lpname};
                next SCAN_MAPPED if ( ($lpname eq 'DATA_WIDTH') or ($lpname eq 'UVC_PREFIX') );
                foreach my $boundspname ( keys %boundsps ) {
                    next SCAN_MAPPED if ($epname eq $boundspname);
                };
                print $autocfgs "    keep soft bind($epname, empty); --eVC field is unbound\n";
                #TODO: remove the next line when appropriete OCP changes are made: https://www.evernote.com/shard/s488/nl/94952566/cc6daf36-9816-4475-98fe-90fa0dc1cf5d
                #TODO: lcfirst usage should be removed, as signals in UVC should have protocol compliant names
                print $autocfgs "    keep ".lcfirst($lpname)."_port_connected == FALSE;\n" if ($bustypename eq 'OCP2_2');
            };
            print $autocfgs "};\n\n";
        };
    };

    print $autocfgs "'>\n";
    print $usercfgs "'>\n" if $userConfigurations;
};

sub log {
    print @_;
    print LOG @_;
}

# Mini Self Checking Test Bench
sub dump_test {
    &log("Writing example instantiation to file 'test.e'\n");
    open(TEST, '>', 'test.e') or die "Error: Cannot create file 'test.e'\n";
    print TEST "// To use this file:\n// specview -p \"load test ; gen ; show data\"\n";
    print TEST "// The file containts instances of all the extended units. The command\n";
    print TEST "// above will compile the code, as a sanity check for script products\n";
    print TEST "// validity.\n";
    print TEST "<'\n\n";
    print TEST "import /vobs/crgn_ip/crgn_dv/evc/crgn_base/e/crgn_base_top.e;\n";
    print TEST "import /vobs/crgn_ip/crgn_dv/evc/crgn_apb_uvc/e/crgn_apb_uvc_top.e;\n";
    print TEST "import /vobs/crgn_ip/crgn_dv/evc/crgn_ahb_uvc/e/crgn_ahb_uvc_top.e;\n";
    print TEST "import /vobs/crgn_ip/crgn_dv/evc/crgn_axi_uvc/e/crgn_axi_uvc_top.e;\n";
    print TEST "import /vobs/crgn_ip/crgn_dv/evc/crgn_ocp_uvc/e/crgn_ocp_uvc_top.e;\n";
    print TEST "import /vobs/crgn_ip/crgn_dv/evc/crgn_cbus_uvc/e/crgn_cbus_uvc_top.e;\n";
    print TEST "import $autocfgsfilename;\n";
    print TEST "import $usercfgsfilename;\n" if $userConfigurations;
    print TEST "\n";
    print TEST "extend sys {\n";
    map { $_ =~ s/(\w+):(\w+):(\w+)/$1: $2 $3 is instance;/ } @busifsfortest;
    print TEST "    $_\n" for @busifsfortest;
    print TEST "};\n\n";
    print TEST "'>\n";
}

sub evc_sp_is_mapped {
    my $evcname = shift;
    my $evcsp   = shift;
    # rh = reversed hash
    my %rh = reverse %{ $evc_to_protocol_signal_mapping{$evcname} };
    if (not exists $rh{$evcsp}) {
        die "Error: illegal eVC simple port '$evcsp' is tried to be manually binded\n" ;
    };
    return 1;
}

sub read_mb_file {
    my $mbfile = shift;
    open(MB_FILE, $mbfile) or die "Error: Cannot open $mbfile\n";
    my @mb = <MB_FILE>;
    close MB_FILE;

    my $mbCnt;

    &log("Warning: the next eVC signals will not be automatically binded to the design: @mb \n");
    foreach my $line (@mb) {
        chomp $line;
        next if ($line =~ /^\s*#.*/); # skip comment lines
        next if ($line =~ /^\s*$/);   # skip blank lines
        if ($line =~ /(\S+)\s*:\s*(\S+)\s*:\s*(\w+)/) {
            my ($evcname, $evcsp, $hdl_path) = ($1, $2, $3);
            if ( &evc_sp_is_mapped($evcname, $evcsp) ) {
                &log("Warning: $evcsp.hdl_path() will be manually binded to $hdl_path (see $manuallyBinded)\n");
                $manuallyBinded_h{$evcsp} = $hdl_path;
            };
        } else {
            die "Error: The format of the parsed line of $manuallyBinded \n$line\nExpected: '<evc_simple_port> : <hdl_path>'\n";
        }
        $mbCnt++;
    }
    return $mbCnt;
}
