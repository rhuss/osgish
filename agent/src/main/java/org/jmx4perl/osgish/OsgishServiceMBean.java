package org.jmx4perl.osgish;

/**
 * MBean for osgish communication between 'osgish' and the osgi-agent bundle.
 *
 * @author roland
 */
public interface OsgishServiceMBean {


    /**
     * Check for state changs on the server side. A client can use this method in order
     * to determine, whether it should update an internal cache.
     *
     * @param pWhat what should be checked for changes
     *        ("bundles","services","all")
     * @param pTimestamp date since what state changes are
     *        taken into account (in epoch seconds)
     * @return true if the state changed, false otherwise
     */
    boolean hasStateChanged(String pWhat,long pTimestamp);
}
