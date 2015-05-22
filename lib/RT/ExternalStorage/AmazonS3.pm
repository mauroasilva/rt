# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use warnings;
use strict;

package RT::ExternalStorage::AmazonS3;

use Role::Basic qw/with/;
with 'RT::ExternalStorage::Backend';

sub S3 {
    my $self = shift;
    if (@_) {
        $self->{S3} = shift;
    }
    return $self->{S3};
}

sub Bucket {
    my $self = shift;
    return $self->{Bucket};
}

sub AccessKeyId {
    my $self = shift;
    return $self->{AccessKeyId};
}

sub SecretAccessKey {
    my $self = shift;
    return $self->{SecretAccessKey};
}

sub BucketObj {
    my $self = shift;
    return $self->S3->bucket($self->Bucket);
}

sub Init {
    my $self = shift;

    if (not Amazon::S3->require) {
        RT->Logger->error("Required module Amazon::S3 is not installed");
        return;
    } elsif (not $self->AccessKeyId) {
        RT->Logger->error("AccessKeyId not provided for AmazonS3");
        return;
    } elsif (not $self->SecretAccessKey) {
        RT->Logger->error("SecretAccessKey not provided for AmazonS3");
        return;
    } elsif (not $self->Bucket) {
        RT->Logger->error("Bucket not provided for AmazonS3");
        return;
    }


    my $S3 = Amazon::S3->new( {
        aws_access_key_id     => $self->AccessKeyId,
        aws_secret_access_key => $self->SecretAccessKey,
        retry                 => 1,
    } );
    $self->S3($S3);

    my $buckets = $S3->bucket( $self->Bucket );
    unless ( $buckets ) {
        RT->Logger->error("Can't list buckets of AmazonS3: ".$S3->errstr);
        return;
    }
    unless ( grep {$_->bucket eq $self->Bucket} @{$buckets->{buckets}} ) {
        my $ok = $S3->add_bucket( {
            bucket    => $self->Bucket,
            acl_short => 'private',
        } );
        unless ($ok) {
            RT->Logger->error("Can't create new bucket '".$self->Bucket."' on AmazonS3: ".$S3->errstr);
            return;
        }
    }

    return $self;
}

sub Get {
    my $self = shift;
    my ($sha) = @_;

    my $ok = $self->BucketObj->get_key( $sha );
    return (undef, "Could not retrieve from AmazonS3:" . $self->S3->errstr)
        unless $ok;
    return ($ok->{value});
}

sub Store {
    my $self = shift;
    my ($sha, $content) = @_;

    # No-op if the path exists already
    return (1) if $self->BucketObj->head_key( $sha );

    $self->BucketObj->add_key(
        $sha => $content
    ) or return (undef, "Failed to write to AmazonS3: " . $self->S3->errstr);

    return (1);
}

RT::Base->_ImportOverlays();

1;
