// go build tls.go
// ./tls sc-cert.pem sc-pkey.pem sc-ca_bundle.pem

package main

import (
        "fmt"
        "io"
        "os"
        "net"
        "crypto/tls"
        "crypto/x509"
        "io/ioutil"
        "log"
)

func sslVerifyCertificateAuthority(client *tls.Conn, tlsConf *tls.Config) {
        err := client.Handshake()
        if err != nil {
                panic(err)
        }
        certs := client.ConnectionState().PeerCertificates
        opts := x509.VerifyOptions{
                DNSName:       client.ConnectionState().ServerName,
                Intermediates: x509.NewCertPool(),
                Roots:         tlsConf.RootCAs,
        }
        for i, cert := range certs {
                if i == 0 {
                        continue
                }
                opts.Intermediates.AddCert(cert)
        }
        _, err = certs[0].Verify(opts)
        if err != nil {
                panic(err)
        }
}

func main() {

        var conn net.Conn

        hostname := "hci-omega-k8s-01-envoy.hciiwf.nimblestorage.com"
        port := "443"
        //URL := "https://hci-omega-k8s-01-envoy.hciiwf.nimblestorage.com:443"
        // cert="/etc/3par/certs/manufacturing/storage-central-cert.pem"
        // key="/etc/3par/certs/manufacturing/storage-central-pkey.pem"
        // caCert:="/opt/tpd/mgmt_files/trustcerts/storagecentral-server-ca_bundle.pem"

        mycert := os.Args[1]
        mykey := os.Args[2]
        ca_cert := os.Args[3]

        cert, err := tls.LoadX509KeyPair(mycert, mykey )

        if err != nil {
                log.Fatal(err)
        }

        // Create a CA certificate pool and add cert.pem to it
        caCert, err := ioutil.ReadFile(ca_cert)
        if err != nil {
                log.Fatal(err)
        }

        clientCertPool := x509.NewCertPool()
        clientCertPool.AppendCertsFromPEM(caCert)

        tlsConfig := &tls.Config{
                ClientAuth:               tls.RequireAndVerifyClientCert,
                Certificates:             []tls.Certificate{cert},
                RootCAs:                  clientCertPool,
                ClientCAs:                clientCertPool,
                PreferServerCipherSuites: true,
                MinVersion:               tls.VersionTLS12,
        }

        tlsConfig.ServerName = hostname

        conn,err = net.Dial("tcp", hostname+":"+port)

        fmt.Printf("Dialing to %s : %s\n", hostname, conn)

        client := tls.Client(conn, tlsConfig)
        if err := client.Handshake(); err != nil {
            conn.Close()
            fmt.Printf("ERROR: Handshake FAILED : %s\n", err)
            switch err.(type) {
                case x509.UnknownAuthorityError:
                        fmt.Printf("x509.UnknownAuthorityError\n")
                     log.Fatal(err)
                case x509.CertificateInvalidError:
                        fmt.Printf("x509.CertificateInvalidError\n")
                     log.Fatal(err)
                default:
                     fmt.Printf("Default \n")
                     log.Fatal(err)
             }
        } else {
            server_certs := client.ConnectionState().PeerCertificates
            for s:=0; s<len(server_certs); s++ {
               fmt.Printf("Subject: %s\n", server_certs[s].Subject)
               fmt.Printf("Issuer: %s\n", server_certs[s].Issuer)
            }
            fmt.Printf("==============================\n")
            verified_chains := client.ConnectionState().VerifiedChains

            for i:=0; i<len(verified_chains); i++ {
                fmt.Printf("Subject: %s\n", verified_chains[i][0].Subject)
                fmt.Printf("Issuer: %s\n", verified_chains[i][0].Issuer)
            }

            buf, err := io.ReadAll(client)
            if err != nil {
               log.Fatal(err)
            }
            fmt.Printf("==> %s\n", buf)
        }

        client.Close()
}

