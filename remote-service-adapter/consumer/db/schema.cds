namespace rsa.samples.consumer;

/**
 * The consumer's own data, in its own database: the remote customer groups point to it (`_Group._Region.Manager`),
 * so one path column goes from a remote system into the database.
 */
entity Regions {
    key code    : String(4);
        Name    : String(40);
        Manager : String(60);
}
