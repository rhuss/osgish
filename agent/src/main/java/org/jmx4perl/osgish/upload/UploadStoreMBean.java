package org.jmx4perl.osgish.upload;

import java.util.Map;

/**
 * MBean for managing the upload store
 *
 * @author roland
 * @since Jan 27, 2010
 */
public interface UploadStoreMBean {

    /**
     * List the content of the upload director
     *
     * @return a map with the filename as key (string) and another map describing the files
     *         properties.
     */
    Map listUploadDirectory();

    /**
     * Delete a certain file in the directory
     *
     * @param pFilename name to delete
     * @return error message if any or null if everything was fine
     */
    String deleteFile(String pFilename);
}
