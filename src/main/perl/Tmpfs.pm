#${PMpre} NCM::Tmpfs${PMpost}

use parent qw(NCM::DummyBlockdevice);

sub devpath
{
    return "tmpfs";
}

1;
