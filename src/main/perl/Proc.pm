#${PMpre} NCM::Proc${PMpost}

use parent qw(NCM::DummyBlockdevice);

sub devpath
{
    return "tmpfs";
}

1;
