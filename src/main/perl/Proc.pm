#${PMpre} NCM::Proc${PMpost}

use parent qw(NCM::DummyBlockdevice);

sub devpath
{
    return "proc";
}

1;
